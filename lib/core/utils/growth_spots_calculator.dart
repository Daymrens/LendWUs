import 'package:fl_chart/fl_chart.dart';
import '../../data/models/contribution.dart';
import '../../data/models/loan.dart';
import '../../data/models/repayment.dart';

class GrowthSpotsCalculator {
  static List<FlSpot> compute(
    List<Contribution> contributions,
    List<Loan> loans,
    List<Repayment> repayments,
    int year,
    int month,
  ) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);

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

    final List<double> contribsByDay = List.filled(lastDayOfMonth.day + 1, 0);
    for (final c in contributions) {
      if (c.date.year == year && c.date.month == month) {
        contribsByDay[c.date.day] += c.amount;
      }
    }
    final List<double> loansByDay = List.filled(lastDayOfMonth.day + 1, 0);
    for (final l in loans) {
      if (l.issuedDate.year == year && l.issuedDate.month == month) {
        loansByDay[l.issuedDate.day] += l.principal;
      }
    }
    final List<double> repayByDay = List.filled(lastDayOfMonth.day + 1, 0);
    for (final r in repayments) {
      if (r.date.year == year && r.date.month == month) {
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
  }
}
