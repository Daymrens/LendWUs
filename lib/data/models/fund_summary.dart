import 'contribution.dart';
import 'loan.dart';
import 'repayment.dart';

class FundSummary {
  final int totalContributions;
  final int totalLoansIssued;
  final int totalRepayments;
  final int totalInterestEarned;
  final int fundBalance;
  final int availableToLoan;

  FundSummary({
    required this.totalContributions,
    required this.totalLoansIssued,
    required this.totalRepayments,
    required this.totalInterestEarned,
    required this.fundBalance,
    required this.availableToLoan,
  });

  static FundSummary compute({
    required List<Contribution> contributions,
    required List<Loan> loans,
    required List<Repayment> repayments,
  }) {
    final totalContributions = contributions.fold<int>(0, (sum, c) => sum + c.amount);
    final totalLoansIssued = loans.fold<int>(0, (sum, l) => sum + l.principal);
    final totalRepayments = repayments.fold<int>(0, (sum, r) => sum + r.amountPaid);

    int totalInterestEarned = 0;
    for (var loan in loans) {
      final loanRepayments = repayments.where((r) => r.loanId == loan.id);
      final totalRepaid = loanRepayments.fold<int>(0, (sum, r) => sum + r.amountPaid);
      final excess = totalRepaid - loan.principal;
      if (excess > 0) totalInterestEarned += excess;
    }

    final fundBalance = totalContributions - totalLoansIssued + totalRepayments;

    int outstanding = 0;
    for (var loan in loans) {
      if (!loan.isFullyRepaid) {
        final loanRepayments = repayments.where((r) => r.loanId == loan.id);
        final totalRepaid = loanRepayments.fold<int>(0, (sum, r) => sum + r.amountPaid);
        final totalDue = loan.principal + (loan.principal * loan.interestRate).round();
        final remaining = totalDue - totalRepaid;
        if (remaining > 0) outstanding += remaining;
      }
    }

    final availableToLoan = fundBalance - outstanding;

    return FundSummary(
      totalContributions: totalContributions,
      totalLoansIssued: totalLoansIssued,
      totalRepayments: totalRepayments,
      totalInterestEarned: totalInterestEarned,
      fundBalance: fundBalance,
      availableToLoan: availableToLoan,
    );
  }
}
