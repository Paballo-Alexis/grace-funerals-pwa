
export const APP_CONFIG = {
  brandName: "Heritage & Grace Parlour",
  tagline: "Compassionate funeral cover and dignified family care",
  supportHours: "24/7 Family Assistance • Mon–Fri 08:00–17:00, Sat 08:00–13:00",
  contact: {
    phoneDisplay: "+27 11 000 0000",
    whatsappE164: "27110000000",
    email: "info@example-parlour.co.za",
    address: "123 Main Road, Sandton, Gauteng"
  },
  colors: {
    royalBlue: "#1B3B82",
    gold: "#C59B27",
    brownInk: "#35261C",
    canvas: "#FAF8F5"
  },
  packages: [
    {
      id: "dignity-basic",
      name: "Dignity Essential",
      monthlyPremiumZar: 145,
      coverAmountZar: 20000,
      waitingPeriodMonths: 6,
      highlights: ["Main member + spouse & children", "Dignified local transfer & casket", "24/7 family guidance"]
    },
    {
      id: "family-standard",
      name: "Family Sanctuary",
      monthlyPremiumZar: 265,
      coverAmountZar: 40000,
      waitingPeriodMonths: 6,
      highlights: ["Extended family options", "Chapel / graveside coordination", "Digital receipts & portal access"]
    },
    {
      id: "executive-complete",
      name: "Complete Legacy",
      monthlyPremiumZar: 420,
      coverAmountZar: 65000,
      waitingPeriodMonths: 6,
      highlights: ["Higher family & dependant limits", "Priority repatriation & floral care", "Dedicated arrangement advisor"]
    }
  ],
  endpoints: {
    // Replace with your live webhook/API URL once backend is ready
    inquiriesUrl: ""
  }
};

export function buildWhatsAppUrl(message) {
  return `https://wa.me/${APP_CONFIG.contact.whatsappE164}?text=${encodeURIComponent(message)}`;
}
