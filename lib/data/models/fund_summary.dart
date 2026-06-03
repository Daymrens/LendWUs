import 'contribution.dart';
import 'loan.dart';
import 'repayment.dart';

class FundSummary {
  final double totalContributions;
  final double totalLoansIssued;
  final double totalRepayments;
  final double totalInterestEarned;
  final double fundBalance;
  final double availableToLoan;

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
    final totalContributions = contributions.fold<double>(0.0, (sum, c) => sum + c.amount);
    final totalLoansIssued = loans.fold<double>(0.0, (sum, l) => sum + l.principal);
    final totalRepayments = repayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);

    double totalInterestEarned = 0.0;
    for (var loan in loans) {
      final loanRepayments = repayments.where((r) => r.loanId == loan.id);
      final totalRepaid = loanRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
      final excess = totalRepaid - loan.principal;
      if (excess > 0) totalInterestEarned += excess;
    }

    final fundBalance = totalContributions - totalLoansIssued + totalRepayments;

    double outstanding = 0.0;
    for (var loan in loans) {
      if (!loan.isFullyRepaid) {
        final loanRepayments = repayments.where((r) => r.loanId == loan.id);
        final totalRepaid = loanRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
        final totalDue = loan.principal + (loan.principal * loan.interestRate);
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
