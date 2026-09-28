import 'package:flutter_test/flutter_test.dart';
import 'package:sinking_fund_app/core/utils/interest_calculator.dart';
import 'package:sinking_fund_app/data/models/loan.dart';
import 'package:sinking_fund_app/data/models/repayment.dart';

void main() {
  group('InterestCalculator', () {
    late Loan testLoan;
    late List<Repayment> testRepayments;

    setUp(() {
      testLoan = Loan(
        id: 'loan1',
        memberId: 'member1',
        principal: 1000000,
        interestRate: 0.10,
        issuedDate: DateTime.now().subtract(const Duration(days: 30)),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        isFullyRepaid: false,
      );

      testRepayments = [
        Repayment(
          id: 'rep1',
          loanId: 'loan1',
          amountPaid: 300000,
          date: DateTime.now().subtract(const Duration(days: 10)),
        ),
        Repayment(
          id: 'rep2',
          loanId: 'loan1',
          amountPaid: 400000,
          date: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ];
    });

    test('calculateLoanInterest returns correct interest', () {
      final interest = InterestCalculator.calculateLoanInterest(testLoan);
      expect(interest, 100000);
    });

    test('calculateTotalDue returns principal + interest', () {
      final totalDue = InterestCalculator.calculateTotalDue(testLoan);
      expect(totalDue, 1100000);
    });

    test('calculateTotalRepaid sums all repayments', () {
      final total = InterestCalculator.calculateTotalRepaid(testRepayments);
      expect(total, 700000);
    });

    test('calculateInterestEarned returns excess over principal', () {
      final fullRepayments = [
        ...testRepayments,
        Repayment(
          id: 'rep3',
          loanId: 'loan1',
          amountPaid: 400000,
          date: DateTime.now(),
        ),
      ];
      final interest = InterestCalculator.calculateInterestEarned(testLoan, fullRepayments);
      expect(interest, 100000);
    });

    test('calculateInterestEarned returns 0 when not fully repaid', () {
      final interest = InterestCalculator.calculateInterestEarned(testLoan, testRepayments);
      expect(interest, 0);
    });

    test('calculateTotalInterestEarned sums across multiple loans', () {
      final loan2 = Loan(
        id: 'loan2',
        memberId: 'member2',
        principal: 500000,
        interestRate: 0.20,
        issuedDate: DateTime.now().subtract(const Duration(days: 10)),
        dueDate: DateTime.now().add(const Duration(days: 50)),
        isFullyRepaid: false,
      );
      final fullRepaymentsLoan1 = [
        ...testRepayments,
        Repayment(
          id: 'rep3',
          loanId: 'loan1',
          amountPaid: 400000,
          date: DateTime.now(),
        ),
      ];
      final repayments2 = [
        Repayment(
          id: 'rep4',
          loanId: 'loan2',
          amountPaid: 600000,
          date: DateTime.now(),
        ),
      ];

      final total = InterestCalculator.calculateTotalInterestEarned(
        [testLoan, loan2],
        [...fullRepaymentsLoan1, ...repayments2],
      );
      expect(total, 100000 + 100000);
    });

    test('calculatePerHeadShare divides interest by heads', () {
      final share = InterestCalculator.calculatePerHeadShare(1000000, 10);
      expect(share, 100000);
    });

    test('calculatePerHeadShare returns 0 for 0 heads', () {
      final share = InterestCalculator.calculatePerHeadShare(1000000, 0);
      expect(share, 0);
    });

    test('calculateRemainingBalance returns correct balance', () {
      final balance = InterestCalculator.calculateRemainingBalance(testLoan, testRepayments);
      expect(balance, 400000);
    });

    test('calculateRemainingBalance returns 0 when fully repaid', () {
      final fullRepayments = [
        ...testRepayments,
        Repayment(
          id: 'rep3',
          loanId: 'loan1',
          amountPaid: 400000,
          date: DateTime.now(),
        ),
      ];
      final balance = InterestCalculator.calculateRemainingBalance(testLoan, fullRepayments);
      expect(balance, 0);
    });

    test('calculateRepaymentProgress returns correct percentage', () {
      final progress = InterestCalculator.calculateRepaymentProgress(testLoan, testRepayments);
      expect(progress, closeTo(0.636, 0.001));
    });

    test('calculateRepaymentProgress returns 0 for 0 total due', () {
      final zeroLoan = Loan(
        id: 'loan0',
        memberId: 'member1',
        principal: 0,
        interestRate: 0.10,
        issuedDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        isFullyRepaid: false,
      );
      final progress = InterestCalculator.calculateRepaymentProgress(zeroLoan, testRepayments);
      expect(progress, 0.0);
    });

    test('isLoanFullyRepaid returns true when total repaid >= total due', () {
      final fullRepayments = [
        ...testRepayments,
        Repayment(
          id: 'rep3',
          loanId: 'loan1',
          amountPaid: 400000,
          date: DateTime.now(),
        ),
      ];
      expect(InterestCalculator.isLoanFullyRepaid(testLoan, fullRepayments), true);
    });

    test('isLoanFullyRepaid returns false when total repaid < total due', () {
      expect(InterestCalculator.isLoanFullyRepaid(testLoan, testRepayments), false);
    });

    test('isLoanFullyRepaid returns true when total repaid exactly equals total due', () {
      final exactRepayments = [
        Repayment(loanId: 'loan1', amountPaid: 1100000, date: DateTime.now()),
      ];
      expect(InterestCalculator.isLoanFullyRepaid(testLoan, exactRepayments), true);
    });
  });

  group('InterestCalculator.calculateMonthlyPayment', () {
    test('calculates monthly payment for a standard loan (simple interest)', () {
      // principal=1000000 centavos (₱10000); totalDue=1120000; monthly=1120000/12≈93333
      final payment = InterestCalculator.calculateMonthlyPayment(1000000, 0.12, 12);
      expect(payment, 93333);
    });

    test('returns principal / term when interest rate is zero', () {
      final payment = InterestCalculator.calculateMonthlyPayment(1200000, 0.0, 12);
      expect(payment, 100000);
    });

    test('handles single month term (simple interest)', () {
      // principal=500000 centavos (₱5000); totalDue=560000; monthly=560000/1=560000
      final payment = InterestCalculator.calculateMonthlyPayment(500000, 0.12, 1);
      expect(payment, 560000);
    });

    test('handles zero rate with single month', () {
      final payment = InterestCalculator.calculateMonthlyPayment(500000, 0.0, 1);
      expect(payment, 500000);
    });
  });
}