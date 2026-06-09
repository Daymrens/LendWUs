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
      final loan = loans.firstWhere((l) => l.id == repayment.loanId, orElse: () => throw Exception('Loan not found: ${repayment.loanId}'));
      
      // Calculate total repaid before THIS repayment
      final priorRepayments = repayments.where((r) => 
        r.loanId == loan.id && 
        (r.date.isBefore(repayment.date) || (r.date.isAtSameMomentAs(repayment.date) && r.id!.compareTo(repayment.id!) < 0))
      );
      final totalPrior = priorRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
      
      final totalWithCurrent = totalPrior + repayment.amountPaid;
      
      if (totalWithCurrent > loan.principal) {
        final currentInterestPortion = totalWithCurrent - (totalPrior > loan.principal ? totalPrior : loan.principal);
        if (currentInterestPortion > 0) {
          interestGained += currentInterestPortion;
        }
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
