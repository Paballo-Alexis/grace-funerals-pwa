# grace-funerals-pwa
FUNERAL PARLOUR WEBSITE 
funeral-parlour-platform/
├── index.html                      # Public Home (hero, clarity steps, packages preview, offline inquiry form)
├── packages.html                   # Public Funeral Cover & Packages comparison page
├── about.html                      # Public About Us (story, facilities, compliance credentials)
├── contact.html                    # Public Inquiry & WhatsApp hub
├── login.html                      # Unified Sign-In (Client Login & Staff/Admin Login switcher)
├── manifest.webmanifest            # PWA install config (app name, start_url, icons, Royal Blue & Cream theme)
├── sw.js                           # Service Worker (offline asset cache + background/online sync triggers)
├── README.md                       # Setup notes, build order, and troubleshooting guide
├── .gitignore                      # Ignores local backups, .env/secrets, and OS/editor junk
│
├── client/                         # Client Portal (protected client views)
│   ├── dashboard.html              # Policy status, waiting periods, dependants, digital barcode/QR, payments & receipts
│   ├── documents.html              # Document uploads (max 3 per slot) + "Request Deletion" button
│   └── appointments.html           # Book, reschedule, and view appointments
│
├── staff/                          # Staff & Admin Operations Portal (RBAC protected)
│   ├── dashboard.html              # Barcode scan input + name/policy search + daily overview & reminders queue
│   ├── registry.html               # Policyholders, dependants, waiting periods + print thermal barcode slip
│   ├── ledger.html                 # Payment recording, digital receipts, cash drawer & daily cash-up verification
│   ├── claims.html                 # Claims workflow, checklists + funeral updates/media folders
│   ├── documents-review.html       # Review & approve/reject client document deletion requests
│   ├── appointments.html           # Manage & confirm client appointments
│   └── admin.html                  # Admin only: RBAC roles, POPIA audit logs, SMS opt-outs & gateway settings
│
├── assets/
│   ├── css/
│   │   ├── tokens.css              # Single source of truth for Royal Blue, Gold, Brown & airy Cream variables
│   │   ├── layout.css              # Page containers, bento grids, responsive spacing
│   │   └── components.css          # Pill buttons, cards, status badges, forms, accordions
│   │
│   ├── js/
│   │   ├── config.js               # Brand info, colors, packages, WhatsApp helper, API endpoints
│   │   ├── pwa-queue.js            # IndexedDB offline inquiry/action queue + auto-sync + scoped logs
│   │   ├── auth-guard.js           # Session & RBAC role checks (Client vs. Staff vs. Admin)
│   │   ├── api-client.js           # Network requests, timeouts, error normalization & scoped logs
│   │   ├── barcode-scanner.js      # Keyboard-wedge barcode listener + client name/ID/policy search
│   │   ├── thermal-print.js        # 58mm/80mm thermal slip layout (Client ID, Name/Surname, Barcode + receipts)
│   │   ├── reminders.js            # Payment reminder stage rules, channel picker & delivery logs
│   │   └── sms-helper.js           # GSM-7 sanitizer, 160-char check & "Reply STOP to opt out" formatter
│   │
│   └── media/                      # Converted .webp images & icons (kebab-case names)
│       ├── hero-family-support-desktop.webp
│       ├── pkg-dignity-essential-card.webp
│       ├── pkg-family-sanctuary-card.webp
│       ├── pkg-complete-legacy-card.webp
│       ├── about-parlour-exterior.webp
│       ├── login-chapel-backdrop.webp
│       ├── brand-icon-192.png
│       └── brand-icon-512.png
│
└── database/                       # SQL files for your database setup
    ├── 01_schema_core.sql          # Packages, policies, dependants, barcodes, waiting periods, appointments
    ├── 02_schema_finance.sql       # Payment ledger, digital receipts, daily cash-ups, claims, reminders, media
    ├── 03_schema_security.sql      # Users, RBAC roles, documents & deletion requests, POPIA audit logs, SMS opt-outs
    └── 04_seed_sample_data.sql     # Sample packages, test policies, cash-up/claim examples & demo roles
