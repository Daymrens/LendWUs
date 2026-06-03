# LendWUs

A Flutter mobile app for managing group sinking funds (paluwagan/family circle savings), powered by Firebase.

## Features

- **Dashboard** - View total fund, members, loans, and interest at a glance
- **Member Management** - Add members with custom heads/shares and track payment status
- **Contributions** - Record member contributions with dates
- **Loan System** - Issue loans with interest rates and track repayments
- **Approvals** - Admin approval workflow for payment and loan requests
- **Reports** - Monthly contribution history and loan summaries
- **Onboarding** - Introduction screens for first-time users
- **Dark UI** - Clean, gradient-based design

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Enable Email/Password and Google Sign-In in [Firebase Console](https://console.firebase.google.com/project/lmsystemm/authentication/providers).

3. Run the app:
```bash
flutter run
```

## Default Credentials

| Role   | Email                     | Password  |
|--------|---------------------------|-----------|
| Admin  | admin@sinkingfund.app     | admin123  |
| Member | member@sinkingfund.app    | member123 |

## Tech Stack

- **Flutter** & Dart
- **Firebase Auth** (email/password + Google Sign-In)
- **Cloud Firestore** (NoSQL database)
- **Riverpod** (state management)
- **go_router** (navigation)
- **fl_chart** (charts)

## Target Platforms

- Android
- iOS
