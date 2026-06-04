# LendWUs

A family circle sinking fund (paluwagan) app: group savings, loans, and returns tracking. Built with **Flutter** (mobile) + **React** (marketing website), powered by **Firebase**.

## Features

- **Dashboard** — Total fund, member count, active loans, interest earned (admin & per-member views)
- **Member Management** — Add/edit members with custom contribution heads; link Firebase accounts
- **Self-Onboarding** — Members join instantly with group code **`LENDWUS`**
- **Contributions** — Record contributions with receipt uploads
- **Loan System** — Issue loans with configurable interest; track repayments with auto-calculated balances
- **Approvals** — Admin approval workflow for payment and loan requests (real-time via StreamProvider)
- **Returns Tracking** — Admin auto-computes end-of-year returns (total interest ÷ heads); members see their per-head share
- **Admin Settings** — Payment limits, currency selection (PHP/USD/EUR), and loan interest percentage
- **Reports** — Monthly contribution history and loan summaries
- **Dark UI** — Clean, gradient-based design
- **Marketing Website** — Responsive React TS landing page at [lmsystemm.web.app](https://lmsystemm.web.app)

## Setup

```bash
# Install Flutter dependencies
flutter pub get

# Install website dependencies
cd website && npm install
```

Enable **Email/Password** and **Google Sign-In** in [Firebase Console](https://console.firebase.google.com/project/lmsystemm/authentication/providers).

Google Sign-In debug SHA-1: `B5:BD:8F:C3:D7:F9:E7:57:83:2B:C8:EE:5D:DC:56:2F:FA:36:BF:FB`

Hardcoded admin emails (auto-linked on Google sign-in):
- `act.drapor@gmail.com`
- `daymrens@gmail.com`

## Run

```bash
# Mobile app
flutter run

# Website (dev)
cd website && npm start

# Website (deploy)
cd website && npm run build
npx firebase deploy --only hosting
```

## Build APK

```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

## Tech Stack

| Layer          | Technology                          |
|----------------|-------------------------------------|
| Mobile         | Flutter & Dart                      |
| Web            | React 18 + TypeScript               |
| State Mgmt     | Riverpod (providers + StreamProvider) |
| Navigation     | go_router                           |
| Auth           | Firebase Auth (email + Google)      |
| Database       | Cloud Firestore (NoSQL)             |
| Backend        | Firebase (Spark plan — no Functions) |
| Hosting        | Firebase Hosting                    |
| Charts         | fl_chart                            |
| Icons          | lucide-react (website)              |

## Project Structure

```
lib/
├── core/
│   ├── theme/          # AppColors, dark theme
│   ├── utils/          # CurrencyFormatter
│   └── widgets/        # LendWUsLogo
├── data/
│   ├── models/         # Loan, Member, PaymentRequest, Repayment, etc.
│   └── repositories/   # Firestore CRUD per collection
├── providers/          # Riverpod providers
└── screens/            # UI screens organized by role/feature

website/
├── public/
└── src/
    ├── App.tsx         # Single-page landing with nav, hero, features, etc.
    ├── App.css         # Fully responsive (mobile hamburger nav)
    └── firebase.ts     # Firebase config
```

## Target Platforms

- Android (8.0+)
- iOS
- Web (marketing site)
