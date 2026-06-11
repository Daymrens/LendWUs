# LendWUs

> A modern **group sinking fund (paluwagan)** app — manage savings, loans, and returns for your family circle or organization. Built with **Flutter** (mobile) + **React** (web), powered by **Firebase**.

---

## 🚀 Features

### 👥 Member Management
- Add/edit members with configurable contribution heads
- Link Firebase accounts via email for self-onboarding
- Join instantly with group code **`LENDWUS`**
- Member profiles with balance tracking, activity logs, and status management
- Head change requests with admin approval workflow

### 💰 Contributions & Receipts
- Record contributions per member with month/year tracking
- Upload receipt images for verification
- View contribution history with summaries
- Pull-to-refresh for real-time updates

### 🏦 Loan System
- Issue loans with configurable interest rates
- Track repayments with auto-calculated remaining balances
- Loan calculator (before applying)
- Amortization schedules
- Member-facing loan dashboard with status indicators

### ✅ Approvals Workflow
- Admin approval for payment requests and loan applications
- Real-time updates via Firestore streams
- Pending, approved, and rejected states
- Bulk loan processing

### 📊 Dashboard & Analytics
- **Admin Dashboard** — Total fund, member count, active loans, interest earned
- **Member Dashboard** — Personal balance, contribution progress, loan status
- **Analytics Dashboard** — Charts, trends, and key metrics
- **Member Performance** — Individual contribution & loan analytics
- **Compliance Reports** — Membership compliance tracking

### 📈 Returns Tracking
- Admin auto-computes end-of-year returns (total interest ÷ heads)
- Members see their per-head share in real-time
- Annual returns distribution

### 🔐 Security & Privacy
- **Biometric authentication** (fingerprint / Face ID) for quick sign-in
- App passcode / PIN lock
- Privacy & security settings screen
- Secure session management

### ⚙️ Admin Controls
- Payment limits configuration
- Currency selection (PHP / USD / EUR)
- Loan interest percentage settings
- **Maintenance mode** — disable non-admin access during updates
- Send push notifications to all members
- Member migration tools
- CSV data export

### 📱 Member Self-Service
- Personal dashboard with balances and progress
- Loan application, calculator, and amortization viewer
- Payment request submission
- Contribution history
- Edit profile, help & support, about screens
- Notification center with real-time updates

### 🎨 Design
- Dark theme with gradient accents
- Clean, modern UI across mobile and web
- Responsive web app (sidebar nav, mobile hamburger menu)
- Consistent branding

### 🌐 Web App
- Full-featured admin panel (17 pages)
- Member portal (14 pages)
- Responsive React + TypeScript with Recharts
- Shared Firebase backend with mobile

---

## 📋 Setup

```bash
# Install Flutter dependencies
flutter pub get

# Install website dependencies
cd website && npm install
```

### Firebase Configuration

Enable **Email/Password** and **Google Sign-In** in the [Firebase Console](https://console.firebase.google.com/project/lmsystemm/authentication/providers).

Google Sign-In debug SHA-1: `B5:BD:8F:C3:D7:F9:E7:57:83:2B:C8:EE:5D:DC:56:2F:FA:36:BF:FB`

Hardcoded admin emails (auto-linked on Google sign-in):
- `act.drapor@gmail.com`
- `daymrens@gmail.com`

---

## ▶️ Run

```bash
# Mobile app
flutter run

# Website (dev)
cd website && npm start

# Website (deploy)
cd website && npm run build
npx firebase deploy --only hosting
```

---

## 📦 Build APK

```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

---

## 🛠 Tech Stack

| Layer          | Technology                            |
|----------------|---------------------------------------|
| Mobile         | Flutter & Dart                        |
| Web            | React 18 + TypeScript                 |
| State Mgmt     | Riverpod (providers + StreamProvider) |
| Navigation     | go_router                             |
| Auth           | Firebase Auth (email + Google)        |
| Database       | Cloud Firestore (NoSQL)               |
| Backend        | Firebase (Spark plan — no Functions)  |
| Hosting        | Firebase Hosting                      |
| Charts         | fl_chart, Recharts                    |
| Biometrics     | local_auth                            |
| Icons          | lucide-react (website)                |

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── firebase/         # Firebase service (auth, Firestore, storage)
│   ├── services/         # Security, notifications, reminders, CSV export
│   └── utils/            # Interest calculator, formatters, helpers
├── data/
│   ├── models/           # 15+ models (Member, Loan, Contribution, ...)
│   └── repositories/     # Firestore CRUD per collection
├── providers/            # 13 Riverpod providers
├── screens/
│   ├── admin/            # 20+ screens (dashboard, members, analytics, ...)
│   ├── member/           # 12 screens (dashboard, loans, payments, ...)
│   ├── auth/             # Login, welcome
│   ├── contributions/    # Contributions screen
│   ├── dashboard/        # Admin dashboard
│   ├── loans/            # Loans screen
│   ├── members/          # Members screen
│   ├── modals/           # 8 modal dialogs
│   ├── notifications/    # Notifications screen
│   ├── onboarding/       # Introduction screen
│   ├── profile/          # Profile, help, about, privacy, edit
│   └── reports/          # Reports screen
└── widgets/              # Wave nav bar, receipt image

website/
└── src/
    ├── pages/
    │   ├── admin/        # 17 admin pages
    │   └── member/       # 14 member pages + modals
    ├── context/          # Auth context
    ├── hooks/            # Web notifications hook
    ├── utils/            # Export, member ID generation, image utils
    ├── App.tsx           # Routes + layouts
    ├── App.css           # Responsive dark theme
    └── firebase.ts       # Firebase config
```

---

## 🎯 Target Platforms

- Android (8.0+)
- iOS
- Web (marketing site)

---

## 🌐 Live Site

Visit **<https://lmsystemm.web.app>** — the marketing website and web admin panel hosted on Firebase Hosting.
