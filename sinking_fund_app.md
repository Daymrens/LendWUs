# Sinking Fund App — Flutter

## Overview
A mobile app for managing a **group sinking fund** (paluwagan/family circle savings). Members contribute regularly, loans can be issued from the pool, and the admin tracks everything in one place.

---

## Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Local DB**: Isar (fast, offline-first)
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
├── app.dart                     # GoRouter setup, theme
├── core/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── app_colors.dart
│   └── utils/
│       └── currency_formatter.dart
├── data/
│   ├── models/
│   │   ├── member.dart          # Isar model
│   │   ├── contribution.dart    # Isar model
│   │   ├── loan.dart            # Isar model
│   │   └── repayment.dart       # Isar model
│   └── repositories/
│       ├── member_repository.dart
│       ├── fund_repository.dart
│       └── loan_repository.dart
├── providers/
│   ├── fund_provider.dart
│   ├── members_provider.dart
│   ├── loans_provider.dart
│   └── reports_provider.dart
└── screens/
    ├── dashboard/
    │   ├── dashboard_screen.dart
    │   └── widgets/
    │       ├── stat_card.dart
    │       ├── action_buttons_row.dart
    │       ├── activity_chart.dart
    │       └── recent_activity_list.dart
    ├── members/
    │   ├── members_screen.dart
    │   └── widgets/
    │       ├── member_tile.dart
    │       └── member_status_badge.dart
    ├── reports/
    │   ├── reports_screen.dart
    │   └── widgets/
    │       ├── report_stat_card.dart
    │       ├── contribution_table.dart
    │       └── loan_summary_list.dart
    └── modals/
        ├── new_contribution_modal.dart
        ├── issue_loan_modal.dart
        └── record_repayment_modal.dart
```

---

## Screens

### 1. Dashboard (`/`)

**Header**
- Title: `Sinking Fund` (bold, large)
- Subtitle: group name (e.g. "Family Circle") + current month/year
- Top-right: refresh/sync icon button

**Stats Grid (2×2)**
| Card | Color | Value |
|------|-------|-------|
| Total Fund | Green gradient | `$12,450` |
| Total Members | Dark surface | `21` |
| Total Loans Issued | Dark surface | `$8,200` |
| Interest Earned | Dark surface | `$245` |

**Action Buttons Row (3 buttons)**
- `New Contribution` — green
- `Issue Loan` — blue
- `Record Repayment` — orange

**Recent Activity Section**
- Header: "Recent Activity" + month comparison toggle (`June vs July`)
- Mini area chart (fl_chart) — shows fund growth comparison between 2 months
- Activity list items:
  - Avatar | Member name | Amount | Timestamp
  - Scrollable, last 10 transactions

---

### 2. Members (`/members`)

**Header**
- Title: `Members`
- Top-right: current user avatar

**Filter Tabs**: `All` | `Active` | `Pending`

**Summary Bar**
- `21 Members` — `Total Contribution: $4,850`

**Member List**
Each tile shows:
- Circular avatar with status ring color
- Member name (bold caps)
- `2 Heads · $150 / $300` (contribution progress)
- Progress bar (thin, colored)
- Status badge: `Paid` (green) | `Pending` (orange) | `50%` (blue pill) | `100%` (green text)

**FAB**: `+` button (green, bottom-right) — opens Add Member modal

---

### 3. Monthly Reports (`/reports`)

**Header**
- Title: `Monthly Reports`
- Month navigator: `< June 2026 >`

**Stats Grid (2×2)**
| Card | Color | Value |
|------|-------|-------|
| Total Contribution | Dark green gradient | `$4,850` |
| Loans Issued | Dark green gradient | `$3,700` |
| Interest Gained | Dark blue gradient | `$185` |
| Ending Balance | Dark blue gradient | `$12,450` |

**Two-column section**
- Left: `Member Contributions` table
  - Columns: Member Name | Contribution Amount | Date
- Right: `Loan Summary` list
  - Items: `Name - $Amount`

---

## Data Models

### Member
```dart
@collection
class Member {
  Id id = Isar.autoIncrement;
  late String name;
  late int headsCount;           // number of "shares" / heads
  late double amountPerHead;     // e.g. 150
  late double totalRequired;     // headsCount * amountPerHead
  String? avatarPath;
  late DateTime joinedAt;
  bool isActive = true;
}
```

### Contribution
```dart
@collection
class Contribution {
  Id id = Isar.autoIncrement;
  late int memberId;
  late double amount;
  late DateTime date;
  String? notes;
}
```

### Loan
```dart
@collection
class Loan {
  Id id = Isar.autoIncrement;
  late int memberId;
  late double principal;
  late double interestRate;      // e.g. 0.03 = 3%
  late DateTime issuedDate;
  late DateTime dueDate;
  bool isFullyRepaid = false;
}
```

### Repayment
```dart
@collection
class Repayment {
  Id id = Isar.autoIncrement;
  late int loanId;
  late double amountPaid;
  late DateTime date;
}
```

---

## Key Features

1. **Dashboard overview** — real-time fund stats pulled from Isar
2. **Add contribution** — modal with member picker, amount input, date
3. **Issue loan** — modal with member picker, principal, interest rate, due date
4. **Record repayment** — modal with loan picker, amount paid
5. **Member management** — add/edit members, track payment status per month
6. **Monthly reports** — auto-computed per month: contributions, loans, interest, balance
7. **Activity chart** — fl_chart area chart comparing 2 months of fund growth
8. **Offline-first** — all data stored locally in Isar, no backend required

---

## pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  riverpod: ^2.5.1
  flutter_riverpod: ^2.5.1
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0
  go_router: ^13.0.0
  fl_chart: ^0.68.0
  intl: ^0.19.0
  google_fonts: ^6.2.1
  flutter_svg: ^2.0.10
  gap: ^3.0.1
  cached_network_image: ^3.3.1

dev_dependencies:
  isar_generator: ^3.1.0
  build_runner: ^2.4.8
```

---

## Notes for Kiro

- Run `flutter pub get` then `dart run build_runner build` to generate Isar schemas
- Use `Google Fonts` package for `Plus Jakarta Sans` + `DM Sans`
- All currency displayed in USD format (`NumberFormat.currency(symbol: '\$')`)
- Charts use `fl_chart` `LineChart` with gradient fill for the activity chart
- Bottom navigation bar: 3 tabs — Dashboard, Members, Reports
- Dark theme only; `ThemeData.dark()` base with custom `ColorScheme`
- Target: Android + iOS
