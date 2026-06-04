import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'fund_provider.dart';
import 'loans_provider.dart';

final fundGrowthSpotsProvider = FutureProvider<List<FlSpot>>((ref) async {
  final fundRepo = ref.watch(fundRepositoryProvider);
  final loanRepo = ref.watch(loanRepositoryProvider);

  final contributions = await fundRepo.getAllContributions();
  final loans = await loanRepo.getAllLoans();
  final repayments = await loanRepo.getAllRepayments();

  final now = DateTime.now();
  final firstDayOfMonth = DateTime(now.year, now.month, 1);
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

  // Calculate balance before this month
  double runningBalance = 0.0;
  
  for (var c in contributions) {
    if (c.date.isBefore(firstDayOfMonth)) {
      runningBalance += c.amount;
    }
  }
  
  for (var l in loans) {
    if (l.issuedDate.isBefore(firstDayOfMonth)) {
      runningBalance -= l.principal;
    }
  }
  
  for (var r in repayments) {
    if (r.date.isBefore(firstDayOfMonth)) {
      runningBalance += r.amountPaid;
    }
  }

  List<FlSpot> spots = [];
  
  for (int day = 1; day <= lastDayOfMonth.day; day++) {
    final currentDate = DateTime(now.year, now.month, day);
    final nextDate = DateTime(now.year, now.month, day + 1);

    // Add contributions on this day
    final dayContribs = contributions.where((c) => 
      c.date.isAfter(currentDate.subtract(const Duration(seconds: 1))) && 
      c.date.isBefore(nextDate)
    );
    for (var c in dayContribs) {
      runningBalance += c.amount;
    }

    // Subtract loans on this day
    final dayLoans = loans.where((l) => 
      l.issuedDate.isAfter(currentDate.subtract(const Duration(seconds: 1))) && 
      l.issuedDate.isBefore(nextDate)
    );
    for (var l in dayLoans) {
      runningBalance -= l.principal;
    }

    // Add repayments on this day
    final dayRepayments = repayments.where((r) => 
      r.date.isAfter(currentDate.subtract(const Duration(seconds: 1))) && 
      r.date.isBefore(nextDate)
    );
    for (var r in dayRepayments) {
      runningBalance += r.amountPaid;
    }

    spots.add(FlSpot(day.toDouble(), runningBalance));
  }

  return spots;
});
