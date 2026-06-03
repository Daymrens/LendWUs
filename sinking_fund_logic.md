# Sinking Fund — Business Logic Spec

## Core Concepts

- **Fund** — the shared pool of money from all member contributions
- **Member** — a participant; can hold 1 or more "heads" (shares)
- **Head** — one unit of contribution obligation (e.g. ₱150/head/month)
- **Contribution** — a payment made by a member toward their head quota
- **Loan** — money borrowed from the fund by a member
- **Repayment** — a payment made by a borrower to return a loan + interest
- **Interest** — earned by the fund on loans issued; grows the total fund

---

## 1. Fund Balance

### Formula
```
Total Fund = Sum of all Contributions - Sum of all Loan Principals Disbursed + Sum of all Repayments Received
```

### Computed fields
```dart
double get totalContributions => contributions.sumBy((c) => c.amount);
double get totalLoansIssued   => loans.sumBy((l) => l.principal);
double get totalRepayments    => repayments.sumBy((r) => r.amountPaid);
double get totalInterestEarned => repayments.sumBy((r) => r.interestPortion);

double get fundBalance =>
    totalContributions - totalLoansIssued + totalRepayments;
```

> **Note**: Loan principal leaves the fund when disbursed. It returns (with interest) as repayments come in. Interest earned = repayment amount that exceeds the original principal portion.

---

## 2. Member Contribution Status

### Per Member Per Month
```
Required Amount = headsCount × amountPerHead
Amount Paid     = Sum of contributions by member within the current month
Remaining       = Required Amount - Amount Paid
Progress %      = (Amount Paid / Required Amount) × 100
```

### Status Logic
```dart
String get paymentStatus {
  if (progress >= 1.0) return 'Paid';
  if (amountPaid == 0)  return 'Pending';
  return '${(progress * 100).toStringAsFixed(0)}%';
}
```

### Status Badge Color
| Status | Color |
|--------|-------|
| Paid | Green `#22C55E` |
| Pending | Orange `#F97316` |
| Partial % | Blue `#3B82F6` |

---

## 3. Loan Issuance Rules

### Eligibility Check (enforce before issuing)
1. Borrower must be an **active member**
2. Requested principal must **not exceed available fund balance**
3. Member must have **no existing fully unpaid loan** (one active loan per member at a time)
4. Loan amount must be **> 0**

### Available to Loan
```dart
double get availableToLoan {
  double outstanding = loans
    .where((l) => !l.isFullyRepaid)
    .sumBy((l) => l.remainingBalance);
  return fundBalance - outstanding;
}
```

### On Loan Issued
- Deduct principal from `availableToLoan` immediately (reserved)
- Create `Loan` record with:
  - `principal`
  - `interestRate` (set by admin, e.g. `0.05` = 5%)
  - `issuedDate` = today
  - `dueDate` = admin-defined (e.g. +30 or +60 days)
  - `isFullyRepaid = false`

---

## 4. Loan Repayment Logic

### Total Amount Due per Loan
```dart
// Simple interest
double get totalAmountDue => principal + (principal * interestRate);
double get interestAmount  => principal * interestRate;
```

### Per Repayment Record
```dart
double get totalRepaid => repayments.where((r) => r.loanId == id).sumBy((r) => r.amountPaid);
double get remainingBalance => totalAmountDue - totalRepaid;
bool   get isFullyRepaid    => remainingBalance <= 0;

// Interest portion already recovered in this repayment batch
double get interestPortion {
  if (totalRepaid <= principal) return 0;
  return totalRepaid - principal;  // anything above principal = interest
}
```

### On Repayment Recorded
1. Add `Repayment` record (loanId, amountPaid, date)
2. Recalculate `remainingBalance`
3. If `remainingBalance <= 0` → set `loan.isFullyRepaid = true`
4. Interest portion flows back into the fund as earned income

---

## 5. Monthly Report Computation

Given a target `month` and `year`:

```dart
MonthlyReport computeReport(int month, int year) {
  final contribs = contributions
    .where((c) => c.date.month == month && c.date.year == year);

  final loansIssued = loans
    .where((l) => l.issuedDate.month == month && l.issuedDate.year == year);

  final repaid = repayments
    .where((r) => r.date.month == month && r.date.year == year);

  return MonthlyReport(
    totalContribution : contribs.sumBy((c) => c.amount),
    loansIssued       : loansIssued.sumBy((l) => l.principal),
    interestGained    : repaid.sumBy((r) => r.interestPortion),
    endingBalance     : fundBalance,  // current running balance
  );
}
```

---

## 6. Activity Chart Data

Compares fund balance growth between two selected months.

```dart
List<FlSpot> getMonthlyGrowthSpots(int month, int year) {
  // Generate daily running balance for the given month
  List<FlSpot> spots = [];
  double running = balanceBeforeMonth(month, year);

  for (int day = 1; day <= daysInMonth(month, year); day++) {
    final date = DateTime(year, month, day);

    // Add contributions on this day
    running += contributions
      .where((c) => isSameDay(c.date, date))
      .sumBy((c) => c.amount);

    // Subtract loans disbursed
    running -= loans
      .where((l) => isSameDay(l.issuedDate, date))
      .sumBy((l) => l.principal);

    // Add repayments received
    running += repayments
      .where((r) => isSameDay(r.date, date))
      .sumBy((r) => r.amountPaid);

    spots.add(FlSpot(day.toDouble(), running));
  }
  return spots;
}
```

---

## 7. Interest Earned Tracking

Interest is **not collected upfront** — it's recognized as earned when repayments exceed the principal:

```dart
double get totalInterestEarned {
  return loans.sumBy((loan) {
    final repaid = repayments
      .where((r) => r.loanId == loan.id)
      .sumBy((r) => r.amountPaid);
    final excess = repaid - loan.principal;
    return excess > 0 ? excess : 0.0;
  });
}
```

---

## 8. Validation Rules Summary

| Action | Rule | Error Message |
|--------|------|---------------|
| New Contribution | amount > 0 | "Amount must be greater than zero" |
| New Contribution | member is active | "Member is not active" |
| New Contribution | amount ≤ remaining required | Warn: "Amount exceeds required — excess recorded as advance" |
| Issue Loan | principal > 0 | "Loan amount must be greater than zero" |
| Issue Loan | principal ≤ availableToLoan | "Insufficient fund balance" |
| Issue Loan | no existing active loan | "Member already has an unpaid loan" |
| Issue Loan | dueDate > today | "Due date must be in the future" |
| Record Repayment | amount > 0 | "Repayment amount must be greater than zero" |
| Record Repayment | amount ≤ remainingBalance | Warn: "Overpayment — excess will be credited to member" |
| Add Member | name not empty | "Name is required" |
| Add Member | headsCount ≥ 1 | "Must have at least 1 head" |
| Add Member | amountPerHead > 0 | "Amount per head must be greater than zero" |

---

## 9. Provider Structure (Riverpod)

```dart
// Fund summary — recomputed whenever contributions/loans/repayments change
final fundSummaryProvider = Provider<FundSummary>((ref) {
  final contribs   = ref.watch(contributionsProvider);
  final loans      = ref.watch(loansProvider);
  final repayments = ref.watch(repaymentsProvider);
  return FundSummary.compute(contribs, loans, repayments);
});

// Members with their current month payment status
final membersWithStatusProvider = Provider<List<MemberWithStatus>>((ref) {
  final members = ref.watch(membersProvider);
  final contribs = ref.watch(contributionsProvider);
  final now = DateTime.now();
  return members.map((m) => MemberWithStatus.of(m, contribs, now.month, now.year)).toList();
});

// Monthly report for selected month
final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final monthlyReportProvider = Provider<MonthlyReport>((ref) {
  final selected = ref.watch(selectedMonthProvider);
  final contribs   = ref.watch(contributionsProvider);
  final loans      = ref.watch(loansProvider);
  final repayments = ref.watch(repaymentsProvider);
  return MonthlyReport.compute(selected.month, selected.year, contribs, loans, repayments);
});
```

---

## 10. Currency — PHP (Philippine Peso)

### Formatter Utility
```dart
// lib/core/utils/currency_formatter.dart
import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    symbol: '₱',
    locale: 'fil_PH',
    decimalDigits: 2,
  );

  /// Format centavos (int) to display string
  /// e.g. 1245000 → "₱12,450.00"
  static String format(int centavos) {
    return _formatter.format(centavos / 100);
  }

  /// Parse display string back to centavos
  static int parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[₱,\s]'), '');
    return (double.parse(cleaned) * 100).round();
  }
}
```

### Storage Rule
- All monetary values stored as **`int` (centavos)** in Isar — no floating point
- `₱150.00` stored as `15000`
- `₱12,450.00` stored as `1245000`
- All arithmetic done in centavos; only convert to display on the UI layer

### Input Field
- Use `TextInputType.numberWithOptions(decimal: true)` for amount fields
- Strip `₱` and `,` before parsing user input
- Prefix input fields with `₱` symbol via `InputDecoration.prefixText`

---

## 11. Edge Cases to Handle

| Case | Handling |
|------|----------|
| Member contributes more than required | Record full amount; flag as advance payment; carry over to next month |
| Partial loan repayment | Allowed — update `remainingBalance`, loan stays open |
| Member with 0 contributions this month | Status = `Pending` |
| Loan due date passed, not fully repaid | Flag loan as `Overdue`; show warning badge on member tile |
| Fund balance goes negative | Block loan issuance; show alert on dashboard |
| Deleting a member with active loan | Block deletion; show error "Cannot remove member with outstanding loan" |
| Two contributions same day same member | Both recorded — cumulative toward monthly quota |
