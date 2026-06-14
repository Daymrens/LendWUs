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

| Status    | Color            |
| --------- | ---------------- |
| Paid      | Green `#22C55E`  |
| Pending   | Orange `#F97316` |
| Partial % | Blue `#3B82F6`   |

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
  * `principal`
  * `interestRate` (set by admin, e.g. `0.05` = 5%)
  * `issuedDate` = today
  * `dueDate` = admin-defined (e.g. +30 or +60 days)
  * `isFullyRepaid = false`

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

## 5. Request & Approval Workflows

Members can self-submit certain actions for admin approval, rather than admins entering everything directly. These correspond to `payment_requests`, `loan_requests`, and `head_change_requests` in Firestore (see `docs/firestore-schema.md` for access rules).

### 5.1 Payment Requests

A member submits a `payment_requests` doc (`memberId`, `amount`, `receiptUrl`, `status: 'pending'`).

On admin approval:
1. Create a matching `contributions` doc with the same `memberId`/`amount`/`receiptUrl`.
2. Set `payment_requests.status = 'approved'`.

Both writes should happen in a single batch — there are no Cloud Functions to guarantee this server-side, so the client must perform the batch write atomically. If the batch fails partway, neither the contribution nor the status change should persist.

On rejection: set `status = 'rejected'`. No `contributions` doc is created.

### 5.2 Loan Requests

Only the member themselves can create a `loan_requests` doc (`memberId`, `principal`, `status: 'pending'`) — admins cannot create requests on a member's behalf via this collection.

On admin approval:
1. Run the **Loan Issuance** eligibility checks from §3 against the requested `principal`.
2. If eligible, create the `loans` doc (per §3 "On Loan Issued").
3. Set `loan_requests.status = 'approved'`.

If the eligibility check fails at approval time (e.g. fund balance dropped since the request was made), do not create the loan — set `status = 'rejected'` and surface the specific reason (insufficient balance, member already has an unpaid loan, etc.) from §9.

### 5.3 Head Change Requests

A member submits a `head_change_requests` doc (`memberId`, `requestedHeads`, `status: 'pending'`) to change their number of contribution heads.

On admin approval:
1. Update `members.headsCount = requestedHeads`.
2. Set `head_change_requests.status = 'approved'`.

**Effective timing**: the schema does not currently track an "effective date" for head changes — a head count change takes effect immediately for `paymentStatus`/`Required Amount` calculations (§2) from the moment `headsCount` is updated, regardless of where in the month the approval happens. If retroactive or next-month-effective changes are needed, this requires an additional field (e.g. `effectiveMonth`) and is **not yet modeled**.

---

## 6. Monthly Report Computation

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

## 7. Activity Chart Data

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

## 8. Interest Earned Tracking

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

## 9. Validation Rules Summary

| Action           | Rule                        | Error Message                                                |
| ---------------- | --------------------------- | ------------------------------------------------------------ |
| New Contribution | amount > 0                  | "Amount must be greater than zero"                           |
| New Contribution | member is active            | "Member is not active"                                       |
| New Contribution | amount ≤ remaining required | Warn: "Amount exceeds required — excess recorded as advance" |
| Issue Loan       | principal > 0               | "Loan amount must be greater than zero"                      |
| Issue Loan       | principal ≤ availableToLoan | "Insufficient fund balance"                                  |
| Issue Loan       | no existing active loan     | "Member already has an unpaid loan"                          |
| Issue Loan       | dueDate > today             | "Due date must be in the future"                             |
| Record Repayment | amount > 0                  | "Repayment amount must be greater than zero"                 |
| Record Repayment | amount ≤ remainingBalance   | Warn: "Overpayment — excess will be credited to member"      |
| Add Member       | name not empty              | "Name is required"                                           |
| Add Member       | headsCount ≥ 1              | "Must have at least 1 head"                                  |
| Add Member       | amountPerHead > 0           | "Amount per head must be greater than zero"                  |

---

## 10. Provider Structure (Riverpod)

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

## 11. Currency — PHP (Philippine Peso)

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

- All monetary values stored as **`int` (centavos)** in Cloud Firestore — no floating point
- `₱150.00` stored as `15000`
- `₱12,450.00` stored as `1245000`
- All arithmetic done in centavos; only convert to display on the UI layer

### Input Field

- Use `TextInputType.numberWithOptions(decimal: true)` for amount fields
- Strip `₱` and `,` before parsing user input
- Prefix input fields with `₱` symbol via `InputDecoration.prefixText`

---

## 12. End-of-Year Returns Calculation

Maps to the `returns` collection (admin-write, member-readable — see `docs/firestore-schema.md`).

### Formula

```
totalInterestEarned = §8 totalInterestEarned (sum of excess repayments over principal, across all loans)
totalHeads          = sum of headsCount across all ACTIVE members at computation time
perHeadShare        = totalInterestEarned / totalHeads   (centavos; guard divide-by-zero)
memberShare(m)      = m.headsCount * perHeadShare
```

```dart
ReturnsResult computeReturns(int year) {
  final totalInterest = totalInterestEarned; // §8
  final activeMembers = members.where((m) => m.active);
  final totalHeads = activeMembers.sumBy((m) => m.headsCount);

  if (totalHeads == 0) {
    throw StateError('Cannot compute returns: totalHeads is 0');
  }

  final perHeadShare = totalInterest ~/ totalHeads; // integer centavos

  final memberShares = {
    for (final m in activeMembers)
      m.id: m.headsCount * perHeadShare,
  };

  return ReturnsResult(
    year: year,
    totalInterestEarned: totalInterest,
    totalHeads: totalHeads,
    perHeadShare: perHeadShare,
    memberShares: memberShares,
  );
}
```

### Rounding

`perHeadShare` uses integer (floor) division on centavos. This means `totalInterestEarned - (perHeadShare * totalHeads)` may leave a small remainder (at most `totalHeads - 1` centavos) undistributed. This remainder stays in the fund balance for the next cycle rather than being distributed — document this behavior for members if precision matters at scale. An alternative (largest-remainder distribution) is not currently implemented.

### Validation

| Rule                  | Error Message                                   |
| --------------------- | ------------------------------------------------ |
| `totalHeads > 0`       | "Cannot compute returns: no active member heads" |
| Only one `returns` doc per `year` | Warn before overwriting an existing year's computation |

### Persisting

Write a single `returns/{docId}` document containing `year`, `totalInterestEarned`, `totalHeads`, `perHeadShare`, and `memberShares` (map of `memberId -> share`). This is a manual, admin-triggered action — there is no scheduled job (no Cloud Functions).

---

## 13. Edge Cases to Handle

| Case                                   | Handling                                                                |
| -------------------------------------- | ----------------------------------------------------------------------- |
| Member contributes more than required  | Record full amount; flag as advance payment; carry over to next month   |
| Partial loan repayment                 | Allowed — update `remainingBalance`, loan stays open                    |
| Member with 0 contributions this month | Status = `Pending`                                                      |
| Loan due date passed, not fully repaid | Flag loan as `Overdue`; show warning badge on member tile               |
| Fund balance goes negative             | Block loan issuance; show alert on dashboard                            |
| Deleting a member with active loan     | Block deletion; show error "Cannot remove member with outstanding loan" |
| Two contributions same day same member | Both recorded — cumulative toward monthly quota                         |
| Loan request approved but balance dropped since submission (§5.2) | Reject with "Insufficient fund balance"; do not create the loan |
| Payment/loan/head-change request approval write fails partway (§5) | Roll back — neither the derived doc nor the request status should persist; surface error and let admin retry |
| `totalHeads == 0` at year-end returns computation (§12) | Block computation; show "no active member heads" error |
| Head count changed mid-month via approved request (§5.3) | New `headsCount` applies immediately to `Required Amount` (§2) — no retroactive/prorated adjustment for the partial month |
