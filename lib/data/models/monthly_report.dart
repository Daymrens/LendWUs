import 'contribution.dart';
import 'loan.dart';
import 'repayment.dart';

class MonthlyReport {
  final int month;
  final int year;
  final int totalContribution;
  final int loansIssued;
  final int interestGained;
  final int endingBalance;

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
    int currentBalance,
  ) {
    final contribs = contributions.where((c) =>
        c.date.month == month && c.date.year == year);

    final loansIssued = loans.where((l) =>
        l.issuedDate.month == month && l.issuedDate.year == year);

    final repaid = repayments.where((r) =>
        r.date.month == month && r.date.year == year);

    int interestGained = 0;
    final processedLoans = <String>{};
    for (var repayment in repaid) {
      if (processedLoans.contains(repayment.loanId)) continue;
      processedLoans.add(repayment.loanId);
      final loan = loans.cast<Loan?>().firstWhere(
        (l) => l?.id == repayment.loanId,
        orElse: () => null,
      );
      if (loan == null) continue;

      final allLoanRepayments = repayments.where((r) => r.loanId == loan.id);
      final allTotalRepaid = allLoanRepayments.fold<int>(0, (sum, r) => sum + r.amountPaid);
      final allInterest = allTotalRepaid > loan.principal ? allTotalRepaid - loan.principal : 0;

      final beforeRepayments = allLoanRepayments.where((r) =>
          r.date.year < year || (r.date.year == year && r.date.month < month));
      final beforeTotalRepaid = beforeRepayments.fold<int>(0, (sum, r) => sum + r.amountPaid);
      final beforeInterest = beforeTotalRepaid > loan.principal ? beforeTotalRepaid - loan.principal : 0;

      interestGained += allInterest - beforeInterest;
    }

    return MonthlyReport(
      month: month,
      year: year,
      totalContribution: contribs.fold<int>(0, (sum, c) => sum + c.amount),
      loansIssued: loansIssued.fold<int>(0, (sum, l) => sum + l.principal),
      interestGained: interestGained,
      endingBalance: currentBalance,
    );
  }
}
