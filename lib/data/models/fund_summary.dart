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

    // Group repayments by loanId for O(1) lookup
    final repaymentsByLoan = <String, List<Repayment>>{};
    for (final r in repayments) {
      repaymentsByLoan.putIfAbsent(r.loanId, () => []).add(r);
    }

    double totalInterestEarned = 0.0;
    double outstanding = 0.0;

    for (var loan in loans) {
      final loanId = loan.id;
      if (loanId == null) continue;

      final loanRepayments = repaymentsByLoan[loanId] ?? [];
      final totalRepaid = loanRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
      
      // Interest earned
      final excess = totalRepaid - loan.principal;
      if (excess > 0) totalInterestEarned += excess;

      // Outstanding balance
      if (!loan.isFullyRepaid) {
        final totalDue = loan.principal + (loan.principal * loan.interestRate);
        final remaining = totalDue - totalRepaid;
        if (remaining > 0) outstanding += remaining;
      }
    }

    final fundBalance = totalContributions - totalLoansIssued + totalRepayments;
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
