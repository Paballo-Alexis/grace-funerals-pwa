const OPT_OUT_SUFFIX = "Reply STOP to opt out";
const MAX_SMS_CHARS = 160;

// Basic GSM-7 character set (standard 7-bit alphabet characters)
const GSM7_REGEX =
  /^[A-Za-z0-9 @£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !"#¤%&'()*+,\-./:;<=>?¡ÄÖÑÜ§¿äöñüà^{}\\[~\]|€]*$/;

function logSms(level, msg, data = null) {
  const prefix = "[SMS:Helper]";
  if (data) {
    console[level](prefix, msg, data);
  } else {
    console[level](prefix, msg);
  }
}

/**
 * Strips emojis/non-GSM-7 characters and normalizes common punctuation
 * so outbound SMS stays in plain GSM-7 text without UCS-2 surprises.
 */
export function toGsm7PlainText(input = "") {
  let text = String(input)
    .replace(/[—–]/g, "-")
    .replace(/[“”]/g, '"')
    .replace(/[‘’]/g, "'")
    .replace(/•/g, "-");

  // Remove any character outside the GSM-7 set (including emojis/Unicode)
  let cleaned = "";
  for (const ch of text) {
    if (GSM7_REGEX.test(ch)) {
      cleaned += ch;
    } else {
      cleaned += " ";
    }
  }

  return cleaned.replace(/\s+/g, " ").trim();
}

/**
 * Formats an SMS message within 160 GSM-7 characters and guarantees
 * the mandatory opt-out notice is present at the end.
 */
export function buildCompliantSms(rawBody, { referenceId = "" } = {}) {
  const suffix = ` ${OPT_OUT_SUFFIX}`;
  const budget = MAX_SMS_CHARS - suffix.length;

  let body = toGsm7PlainText(rawBody);
  if (body.length > budget) {
    const trimmed = body.slice(0, Math.max(0, budget - 3)).trimEnd();
    body = `${trimmed}...`;
    logSms("warn", "SMS body truncated to fit 160-char limit", {
      referenceId,
      originalLength: rawBody.length,
      finalBudget: budget
    });
  }

  const message = `${body}${suffix}`;
  const isGsm7 = GSM7_REGEX.test(message);

  if (!isGsm7 || message.length > MAX_SMS_CHARS) {
    logSms("error", "SMS failed GSM-7 or length check", {
      referenceId,
      length: message.length,
      isGsm7
    });
  } else {
    logSms("log", "Built compliant SMS", {
      referenceId,
      length: message.length
    });
  }

  return {
    message,
    charCount: message.length,
    maxChars: MAX_SMS_CHARS,
    isGsm7,
    withinSingleSms: message.length <= MAX_SMS_CHARS && isGsm7
  };
}

/**
 * Normalizes South African mobile numbers (e.g. 0821234567 -> +27821234567).
 */
export function normalizeZaMsisdn(phone = "") {
  const digits = String(phone).replace(/\D/g, "");
  if (digits.startsWith("27") && digits.length === 11) return `+${digits}`;
  if (digits.startsWith("0") && digits.length === 10) return `+27${digits.slice(1)}`;
  return phone.trim();
}

/**
 * Gate helper before dispatching SMS: blocks opted-out numbers and logs cleanly.
 */
export async function dispatchSmsWithGuards({
  to,
  rawBody,
  category = "transactional",
  relatedEntityId = "",
  optedOutSet = new Set(),
  sendFn
}) {
  const msisdn = normalizeZaMsisdn(to);
  if (optedOutSet.has(msisdn)) {
    logSms("warn", "Skipped SMS because recipient opted out (STOP)", {
      msisdn,
      category,
      relatedEntityId
    });
    return { status: "SKIPPED_OPT_OUT", msisdn };
  }

  const built = buildCompliantSms(rawBody, { referenceId: relatedEntityId });
  if (!built.withinSingleSms) {
    return { status: "REJECTED_ENCODING_OR_LENGTH", msisdn, ...built };
  }

  if (typeof sendFn !== "function") {
    logSms("log", "Dry-run SMS payload ready (no sendFn provided)", {
      msisdn,
      category,
      relatedEntityId,
      message: built.message
    });
    return { status: "READY_DRY_RUN", msisdn, ...built };
  }

  const result = await sendFn({
    to: msisdn,
    message: built.message,
    category,
    relatedEntityId
  });
  logSms("log", "Dispatched SMS via gateway", { msisdn, category, relatedEntityId });
  return { status: "SENT", msisdn, ...built, providerResult: result };
}
