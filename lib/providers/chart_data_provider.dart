import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'members_provider.dart';
import 'loans_provider.dart';
import 'members_with_status_provider.dart';

class MonthlyTrend {
  final String label;
  final double contributions;
  final double loans;
  final double repayments;
  MonthlyTrend({
    required this.label,
    required this.contributions,
    required this.loans,
    required this.repayments,
  });
}

class CollectionRateTrend {
  final String label;
  final double rate;
  final double collected;
  final double required;
  CollectionRateTrend({
    required this.label,
    required this.rate,
    required this.collected,
    required this.required,
  });
}

final monthlyTrendsProvider = FutureProvider<List<MonthlyTrend>>((ref) async {
  final contributions = [...?ref.watch(contributionsStreamProvider).asData?.value];
  final loans = [...?ref.watch(loansStreamProvider).asData?.value];
  final repayments = [...?ref.watch(repaymentsStreamProvider).asData?.value];

  const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final now = DateTime.now();
  final trends = <MonthlyTrend>[];

  for (int i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    final month = d.month;
    final year = d.year;

    final monthContribs = contributions
        .where((c) => c.date.month == month && c.date.year == year)
        .fold<double>(0.0, (s, c) => s + c.amount);
    final monthLoans = loans
        .where((l) => l.issuedDate.month == month && l.issuedDate.year == year)
        .fold<double>(0.0, (s, l) => s + l.principal);
    final monthRepays = repayments
        .where((r) => r.date.month == month && r.date.year == year)
        .fold<double>(0.0, (s, r) => s + r.amountPaid);

    trends.add(MonthlyTrend(
      label: '${monthNames[month]} ${year.toString().substring(2)}',
      contributions: monthContribs,
      loans: monthLoans,
      repayments: monthRepays,
    ));
  }

  return trends;
});

final collectionRateTrendProvider = FutureProvider<List<CollectionRateTrend>>((ref) async {
  final contributions = [...?ref.watch(contributionsStreamProvider).asData?.value];
  final members = [...?ref.watch(membersStreamProvider).asData?.value];

  const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final now = DateTime.now();
  final trends = <CollectionRateTrend>[];

  final activeMembers = members.where((m) => m.isActive).toList();

  for (int i = 5; i >= 0; i--) {
    final d = DateTime(now.year, now.month - i, 1);
    final month = d.month;
    final year = d.year;

    final monthContribs = contributions
        .where((c) => c.date.month == month && c.date.year == year)
        .fold<double>(0.0, (s, c) => s + c.amount);

    final totalRequired = activeMembers.fold<double>(
      0.0,
      (s, m) => s + (m.totalRequired > 0 ? m.totalRequired : m.headsCount * m.amountPerHead),
    );

    final rate = totalRequired > 0 ? (monthContribs / totalRequired) * 100 : 0.0;

    trends.add(CollectionRateTrend(
      label: '${monthNames[month]} ${year.toString().substring(2)}',
      rate: rate,
      collected: monthContribs,
      required: totalRequired,
    ));
  }

  return trends;
});
