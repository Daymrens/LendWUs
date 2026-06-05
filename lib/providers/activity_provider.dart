import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'members_provider.dart';
import 'loans_provider.dart';

final fundGrowthSpotsProvider = FutureProvider<List<FlSpot>>((ref) async {
  final contributions = [...?ref.watch(contributionsStreamProvider).asData?.value];
  final loans = [...?ref.watch(loansStreamProvider).asData?.value];
  final repayments = [...?ref.watch(repaymentsStreamProvider).asData?.value];

  final now = DateTime.now();
  final firstDayOfMonth = DateTime(now.year, now.month, 1);
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

  // Balance carried over from prior months.
  double runningBalance = 0.0;
  for (final c in contributions) {
    if (c.date.isBefore(firstDayOfMonth)) runningBalance += c.amount;
  }
  for (final l in loans) {
    if (l.issuedDate.isBefore(firstDayOfMonth)) runningBalance -= l.principal;
  }
  for (final r in repayments) {
    if (r.date.isBefore(firstDayOfMonth)) runningBalance += r.amountPaid;
  }

  // Bucket this-month movements by day-of-month so the per-day loop is O(D).
  final List<double> contribsByDay = List.filled(lastDayOfMonth.day + 1, 0);
  for (final c in contributions) {
    if (c.date.year == now.year && c.date.month == now.month) {
      contribsByDay[c.date.day] += c.amount;
    }
  }
  final List<double> loansByDay = List.filled(lastDayOfMonth.day + 1, 0);
  for (final l in loans) {
    if (l.issuedDate.year == now.year && l.issuedDate.month == now.month) {
      loansByDay[l.issuedDate.day] += l.principal;
    }
  }
  final List<double> repayByDay = List.filled(lastDayOfMonth.day + 1, 0);
  for (final r in repayments) {
    if (r.date.year == now.year && r.date.month == now.month) {
      repayByDay[r.date.day] += r.amountPaid;
    }
  }

  final spots = <FlSpot>[];
  for (int day = 1; day <= lastDayOfMonth.day; day++) {
    runningBalance += contribsByDay[day];
    runningBalance -= loansByDay[day];
    runningBalance += repayByDay[day];
    spots.add(FlSpot(day.toDouble(), runningBalance));
  }

  return spots;
});
