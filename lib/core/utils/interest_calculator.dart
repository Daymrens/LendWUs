import '../../data/models/loan.dart';
import '../../data/models/repayment.dart';

class InterestCalculator {
  static double calculateLoanInterest(Loan loan) {
    return loan.principal * loan.interestRate;
  }

  static double calculateTotalDue(Loan loan) {
    return loan.principal + calculateLoanInterest(loan);
  }

  static double calculateTotalRepaid(List<Repayment> repayments) {
    return repayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
  }

  static double calculateInterestEarned(Loan loan, List<Repayment> repayments) {
    final totalRepaid = calculateTotalRepaid(repayments);
    final excess = totalRepaid - loan.principal;
    return excess > 0 ? excess : 0.0;
  }

  static double calculateTotalInterestEarned(
    List<Loan> loans,
    List<Repayment> repayments,
  ) {
    double totalInterest = 0.0;
    for (var loan in loans) {
      final loanRepayments = repayments.where((r) => r.loanId == loan.id);
      totalInterest += calculateInterestEarned(loan, loanRepayments.toList());
    }
    return totalInterest;
  }

  static double calculatePerHeadShare(double totalInterest, int totalHeads) {
    return totalHeads > 0 ? totalInterest / totalHeads : 0.0;
  }

  static double calculateRemainingBalance(Loan loan, List<Repayment> repayments) {
    final totalDue = calculateTotalDue(loan);
    final totalRepaid = calculateTotalRepaid(repayments);
    return (totalDue - totalRepaid).clamp(0.0, double.infinity);
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

  static double calculateMonthlyPayment(double principal, double annualRateDecimal, int termMonths) {
    final monthlyRate = annualRateDecimal / 12;
    if (monthlyRate <= 0 || termMonths <= 0) return principal / (termMonths > 0 ? termMonths : 1);
    final factor = (1 + monthlyRate);
    final powFactor = _pow(factor, termMonths);
    return principal * monthlyRate * powFactor / (powFactor - 1);
  }

  static double _pow(double x, int n) {
    double result = 1.0;
    for (var i = 0; i < n; i++) {
      result *= x;
    }
    return result;
  }
}
