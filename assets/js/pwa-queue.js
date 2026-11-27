
const DB_NAME = "parlour_pwa_db";
const DB_VERSION = 1;
const STORE_NAME = "queued_inquiries";

function log(scope, msg, data = null) {
  const prefix = `[PWA:${scope}]`;
  data ? console.log(prefix, msg, data) : console.log(prefix, msg);
}

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        const store = db.createObjectStore(STORE_NAME, { keyPath: "traceId" });
        store.createIndex("status", "status", { unique: false });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function enqueueInquiry(payload) {
  const traceId = `inq_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
  const record = {
    traceId,
    payload,
    status: "queued",
    attempts: 0,
    createdAt: new Date().toISOString(),
    lastError: null
  };

  const db = await openDb();
  await new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    tx.objectStore(STORE_NAME).put(record);
    tx.oncomplete = resolve;
    tx.onerror = () => reject(tx.error);
  });

  log("Queue", "Saved inquiry offline", { traceId });
  return record;
}

export async function flushQueuedInquiries(endpointUrl) {
  if (!navigator.onLine) {
    log("Sync", "Skipped flush: device is offline");
    return { flushed: 0, remaining: await countPending() };
  }
  if (!endpointUrl) {
    log("Sync", "No inquiriesUrl configured yet; keeping items queued locally");
    return { flushed: 0, remaining: await countPending() };
  }

  const db = await openDb();
  const items = await new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readonly");
    const req = tx.objectStore(STORE_NAME).getAll();
    req.onsuccess = () => resolve(req.result.filter((r) => r.status !== "synced"));
    req.onerror = () => reject(req.error);
  });

  let flushed = 0;
  for (const item of items) {
    try {
      const res = await fetch(endpointUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ traceId: item.traceId, ...item.payload })
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      await new Promise((resolve, reject) => {
        const tx = db.transaction(STORE_NAME, "readwrite");
        tx.objectStore(STORE_NAME).put({
          ...item,
          status: "synced",
          syncedAt: new Date().toISOString(),
          lastError: null
        });
        tx.oncomplete = resolve;
        tx.onerror = () => reject(tx.error);
      });
      flushed += 1;
      log("Sync", "Synced inquiry", { traceId: item.traceId });
    } catch (err) {
      await new Promise((resolve, reject) => {
        const tx = db.transaction(STORE_NAME, "readwrite");
        tx.objectStore(STORE_NAME).put({
          ...item,
          status: "failed_retryable",
          attempts: item.attempts + 1,
          lastError: String(err.message || err)
        });
        tx.oncomplete = resolve;
        tx.onerror = () => reject(tx.error);
      });
      log("Sync", "Retryable sync failure", { traceId: item.traceId, error: String(err) });
    }
  }

  return { flushed, remaining: await countPending() };
}

export async function countPending() {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readonly");
    const req = tx.objectStore(STORE_NAME).getAll();
    req.onsuccess = () => resolve(req.result.filter((r) => r.status !== "synced").length);
    req.onerror = () => reject(req.error);
  });
}

export function initSyncListeners(getEndpointUrl, onAfterSync) {
  const run = async () => {
    const result = await flushQueuedInquiries(getEndpointUrl());
    if (onAfterSync) onAfterSync(result);
  };
  window.addEventListener("online", run);
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") run();
  });
}
