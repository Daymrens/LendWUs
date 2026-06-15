# Sinking Fund App — Flutter

## Overview
A mobile app for managing a **group sinking fund** (paluwagan/family circle savings). Members contribute regularly, loans can be issued from the pool, and the admin tracks everything in one place. Includes a **treasurer role** for bank-receipt confirmation before admin approval.

---

## Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod (providers + StreamProvider)
- **Backend**: Firebase Auth + Cloud Firestore (Spark plan — no Cloud Functions)
- **Charts**: fl_chart
- **Navigation**: go_router
- **UI Theme**: Custom dark theme — deep navy base, green/blue/orange accents

---

## Design Language (2026 Modern Mobile)

- **Color Palette**
  - Background: `#0D1117` (deep dark)
  - Surface cards: `#161B22` / `#1C2333`
  - Primary accent: `#22C55E` (green — contributions)
  - Secondary accent: `#3B82F6` (blue — loans)
  - Warning accent: `#F97316` (orange — repayments/pending)
  - Text primary: `#F0F6FC`
  - Text muted: `#8B949E`

- **Typography**
  - Display/headers: `Clash Display` or `Plus Jakarta Sans` (bold, heavy weight)
  - Body/labels: `DM Sans` or `Geist`

- **Card style**: Rounded corners (16–20px), subtle gradient fills (dark green to dark navy for contribution cards, dark blue gradient for stats), glass morphism-lite with slight border glow

- **Buttons**: Full-width pill style for primary actions; color-coded (green = contribute, blue = loan, orange = repayment)

- **Micro-interactions**: Ripple on tap, smooth page transitions, animated counters on stat cards

- **Avatar style**: Circular avatars with colored ring based on payment status (green = paid, orange = pending)

- **Progress bars**: Thin, rounded, colored by completion % (green = 100%, blue = partial, orange/red = pending)

---

## App Structure

```
lib/
├── main.dart
├── app.dart                     # GoRouter setup, theme, auth redirect
├── core/
│   ├── firebase/
│   │   └── firebase_service.dart # Firebase init, emulator config
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── app_colors.dart
│   ├── services/
│   │   ├── security_service.dart  # Biometric, passcode, OTP, backup codes
│   │   ├── notification_service.dart # FCM token management
│   │   ├── notification_watcher.dart  # Real-time notification listener
│   │   └── csv_export_service.dart
│   ├── utils/
│   │   ├── currency_formatter.dart
│   │   ├── interest_calculator.dart
│   │   └── member_id_generator.dart
│   └── widgets/
│       └── lendwus_logo.dart
├── data/
│   ├── models/
│   │   ├── member.dart
│   │   ├── contribution.dart
│   │   ├── loan.dart
│   │   ├── repayment.dart
│   │   ├── loan_request.dart
│   │   ├── payment_request.dart
│   │   ├── head_change_request.dart
│   │   ├── user.dart              # isTreasurer flag
│   │   ├── app_settings.dart      # treasurerEmails list
│   │   ├── activity_log.dart
│   │   └── notification_model.dart
│   └── repositories/
│       ├── member_repository.dart
│       ├── fund_repository.dart
│       ├── loan_repository.dart
│       ├── contribution_repository.dart
│       ├── payment_request_repository.dart
│       ├── notification_repository.dart
│       └── settings_repository.dart
├── providers/
│   ├── auth_provider.dart
│   ├── settings_provider.dart
│   ├── members_provider.dart
│   ├── loans_provider.dart
│   ├── contributions_provider.dart
│   └── reports_provider.dart
└── screens/
    ├── admin/
    │   ├── admin_dashboard.dart
    │   ├── admin_settings_screen.dart  # Treasurer Emails section
    │   └── ...
    ├── member/
    │   ├── member_dashboard_screen.dart
    │   ├── member_contributions_screen.dart  # Tappable detail modal
    │   └── ...
    ├── treasurer/
    │   └── treasurer_dashboard_screen.dart  # Bank confirmation UI
    ├── auth/
    ├── contributions/
    ├── dashboard/
    ├── loans/
    ├── members/
    ├── modals/
    ├── notifications/
    ├── onboarding/
    ├── profile/
    └── reports/
```

---

## Screens

### Roles

Three user roles: **admin** (full control), **member** (self-service), **treasurer** (member with `isTreasurer: true` — can confirm bank receipts on payment requests). Routing uses GoRouter redirect guards based on role.

### Navigation

- **Admin shell**: bottom nav with Dashboard, Members, Loans, Contributions, Reports, and a "More" sheet for 10+ additional screens.
- **Member shell**: bottom nav with Home, Loans, Contributions, Requests, Treasurer (conditional — only when `isTreasurer == true`), Profile.

### Key Screens

#### Admin Dashboard
Stats grid (total fund, members, loans issued, interest earned), recent activity chart, member payment status overview.

### 2. Members
Member list with filter tabs (All/Active/Pending), progress bars, status badges. FAB for adding new members.

### 3. Contributions
Member contribution list with pull-to-refresh. Tapping a recent contribution opens a bottom-sheet detail modal showing full timestamp, receipt image, member, amount, period, and notes.

### 4. Treasurer Dashboard
Available only to users with `isTreasurer: true`. Lists all pending payment requests with a "Confirm Bank Received" button per item. Confirmed requests show a badge. Notifies admin on confirmation.

---

## Data Models (Firestore)

All data stored in **Cloud Firestore** (not Isar). See `firestore-schema.md` for complete field definitions.

### Key Models
- `User` — `role`, `memberId`, `email`, `isTreasurer`, `fcmToken`
- `Member` — `name`, `headsCount`, `amountPerHead`, `linkedEmail`, `isActive`
- `Contribution` — `memberId`, `amount`, `month`, `year`, `receiptUrl`
- `Loan` — `memberId`, `principal`, `interestRate`, `issuedDate`, `dueDate`, `isFullyRepaid`
- `Repayment` — `loanId`, `amountPaid`, `date`
- `PaymentRequest` — `memberId`, `type`, `amount`, `receiptUrl`, `status`, `bankConfirmed`, `bankConfirmedAt`, `bankConfirmedBy`
- `AppSettings` — `adminEmails`, `treasurerEmails`, `currencySymbol`, `loanInterestPercent`, `groupCode`

---

## Key Features

1. **Dashboard overview** — real-time fund stats from Firestore
2. **Add contribution** — modal with member picker, amount input, receipt
3. **Issue loan** — modal with member picker, principal, interest rate, due date
4. **Record repayment** — modal with loan picker, amount paid
5. **Member management** — add/edit members, track payment status per month
6. **Monthly reports** — auto-computed per month: contributions, loans, interest, balance
7. **Activity chart** — fl_chart area chart comparing month-over-month fund growth
8. **Contribution receipt upload** — base64 image data in Firestore (no Storage needed on Spark)
9. **Self-service payment requests** — members submit contributions/repayments for admin approval
10. **Loan requests** — members apply for loans, admin approves/rejects
11. **Head change requests** — members request head count changes, admin approves
12. **Notifications** — FCM push for approvals, treasurer confirmations, admin alerts
13. **Treasurer role** — bank receipt confirmation workflow before admin approval
14. **Biometric / passcode auth** — local_auth for quick sign-in
15. **CSV export** — admin can export data to CSV

---

## pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  firebase_core: ^2.30.0
  firebase_auth: ^4.19.0
  cloud_firestore: ^4.17.0
  firebase_messaging: ^14.9.0
  google_sign_in: ^6.2.1
  go_router: ^13.0.0
  fl_chart: ^0.68.0
  intl: ^0.19.0
  local_auth: ^2.2.0
  share_plus: ^9.0.0
  url_launcher: ^6.2.6
  cached_network_image: ^3.3.1
  image_picker: ^1.0.7
```

---

## Notes for Kiro

- Run `flutter pub get` before building
- Use the Firebase Local Emulator Suite for testing Firestore rules changes
- All currency displayed via `CurrencyFormatter` (supports PHP/USD/EUR)
- Bottom navigation: Admin shell (Dashboard, Members, Loans, Contributions, Reports, More) and Member shell (Home, Loans, Contributions, Requests, Treasurer if flag set, Profile)
- Dark theme only; `ThemeData.dark()` base with custom `ColorScheme`
- Target: Android + iOS
- **Spark plan constraints**: no Cloud Functions, no Firebase Storage (base64 receipts instead)
