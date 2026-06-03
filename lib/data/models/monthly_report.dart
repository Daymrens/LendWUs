import 'contribution.dart';
import 'loan.dart';
import 'repayment.dart';

class MonthlyReport {
  final int month;
  final int year;
  final double totalContribution;
  final double loansIssued;
  final double interestGained;
  final double endingBalance;

  MonthlyReport({
    required this.month,
    required this.year,
    required this.totalContribution,
    required this.loansIssued,
    required this.interestGained,
    required this.endingBalance,
  });

  static MonthlyReport compute(
    int month,
    int year,
    List<Contribution> contributions,
    List<Loan> loans,
    List<Repayment> repayments,
    double currentBalance,
  ) {
    final contribs = contributions.where((c) =>
        c.date.month == month && c.date.year == year);

    final loansIssued = loans.where((l) =>
        l.issuedDate.month == month && l.issuedDate.year == year);

    final repaid = repayments.where((r) =>
        r.date.month == month && r.date.year == year);

    double interestGained = 0.0;
    for (var repayment in repaid) {
      final loan = loans.firstWhere((l) => l.id == repayment.loanId);
      final loanRepayments = repayments.where((r) => r.loanId == loan.id);
      final totalRepaid = loanRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);

      if (totalRepaid > loan.principal) {
        final interest = totalRepaid - loan.principal;
        interestGained += interest;
      }
    }

    return MonthlyReport(
      month: month,
      year: year,
      totalContribution: contribs.fold<double>(0.0, (sum, c) => sum + c.amount),
      loansIssued: loansIssued.fold<double>(0.0, (sum, l) => sum + l.principal),
      interestGained: interestGained,
      endingBalance: currentBalance,
    );
  }
}
