import '../../data/models/loan.dart';
import '../../data/models/repayment.dart';

/// Simple-interest calculator.
/// All monetary values are in integer centavos.
/// interestRate is a decimal (e.g. 0.05 = 5%).
/// This implementation uses flat one-time simple interest (not amortized/reducing balance).
/// See sinking_fund_logic.md §3 for details.
class InterestCalculator {
  static int calculateLoanInterest(Loan loan) {
    return (loan.principal * loan.interestRate).round();
  }

  static int calculateTotalDue(Loan loan) {
    return loan.principal + calculateLoanInterest(loan);
  }

  static int calculateTotalRepaid(List<Repayment> repayments) {
    return repayments.fold<int>(0, (sum, r) => sum + r.amountPaid);
  }

  static int calculateInterestEarned(Loan loan, List<Repayment> repayments) {
    final totalRepaid = calculateTotalRepaid(repayments);
    final excess = totalRepaid - loan.principal;
    return excess > 0 ? excess : 0;
  }

  static int calculateTotalInterestEarned(
    List<Loan> loans,
    List<Repayment> repayments,
  ) {
    int totalInterest = 0;
    for (var loan in loans) {
      final loanRepayments = repayments.where((r) => r.loanId == loan.id);
      totalInterest += calculateInterestEarned(loan, loanRepayments.toList());
    }
    return totalInterest;
  }

  static int calculatePerHeadShare(int totalInterest, int totalHeads) {
    return totalHeads > 0 ? (totalInterest / totalHeads).round() : 0;
  }

  static int calculateRemainingBalance(Loan loan, List<Repayment> repayments) {
    final totalDue = calculateTotalDue(loan);
    final totalRepaid = calculateTotalRepaid(repayments);
    final remaining = totalDue - totalRepaid;
    return remaining > 0 ? remaining : 0;
  }

  static double calculateRepaymentProgress(Loan loan, List<Repayment> repayments) {
    final totalDue = calculateTotalDue(loan);
    if (totalDue <= 0) return 0.0;
    final totalRepaid = calculateTotalRepaid(repayments);
    return (totalRepaid / totalDue).clamp(0.0, 1.0);
  }

  static bool isLoanFullyRepaid(Loan loan, List<Repayment> repayments) {
    final totalDue = calculateTotalDue(loan);
    final totalRepaid = calculateTotalRepaid(repayments);
    return totalRepaid >= totalDue;
  }

  /// Simple-interest monthly payment: total amount due divided by term.
  /// principal is in centavos. Returns monthly payment in centavos.
  static int calculateMonthlyPayment(int principal, double annualRateDecimal, int termMonths) {
    if (termMonths <= 0) return principal;
    final totalDue = principal + (principal * annualRateDecimal).round();
    return (totalDue / termMonths).round();
  }
}
