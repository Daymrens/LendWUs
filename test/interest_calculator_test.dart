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
        principal: 10000.0,
        interestRate: 0.10,
        issuedDate: DateTime.now().subtract(const Duration(days: 30)),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        isFullyRepaid: false,
      );

      testRepayments = [
        Repayment(
          id: 'rep1',
          loanId: 'loan1',
          amountPaid: 3000.0,
          date: DateTime.now().subtract(const Duration(days: 10)),
        ),
        Repayment(
          id: 'rep2',
          loanId: 'loan1',
          amountPaid: 4000.0,
          date: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ];
    });

    test('calculateLoanInterest returns correct interest', () {
      final interest = InterestCalculator.calculateLoanInterest(testLoan);
      expect(interest, 1000.0);
    });

    test('calculateTotalDue returns principal + interest', () {
      final totalDue = InterestCalculator.calculateTotalDue(testLoan);
      expect(totalDue, 11000.0);
    });

    test('calculateTotalRepaid sums all repayments', () {
      final total = InterestCalculator.calculateTotalRepaid(testRepayments);
      expect(total, 7000.0);
    });

    test('calculateInterestEarned returns excess over principal', () {
      final fullRepayments = [
        ...testRepayments,
        Repayment(
          id: 'rep3',
          loanId: 'loan1',
          amountPaid: 4000.0,
          date: DateTime.now(),
        ),
      ];
      final interest = InterestCalculator.calculateInterestEarned(testLoan, fullRepayments);
      expect(interest, 1000.0);
    });

    test('calculateInterestEarned returns 0 when not fully repaid', () {
      final interest = InterestCalculator.calculateInterestEarned(testLoan, testRepayments);
      expect(interest, 0.0);
    });

    test('calculateTotalInterestEarned sums across multiple loans', () {
      final loan2 = Loan(
        id: 'loan2',
        memberId: 'member2',
        principal: 5000.0,
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
          amountPaid: 4000.0,
          date: DateTime.now(),
        ),
      ];
      final repayments2 = [
        Repayment(
          id: 'rep4',
          loanId: 'loan2',
          amountPaid: 6000.0,
          date: DateTime.now(),
        ),
      ];

      final total = InterestCalculator.calculateTotalInterestEarned(
        [testLoan, loan2],
        [...fullRepaymentsLoan1, ...repayments2],
      );
      expect(total, 1000.0 + 1000.0);
    });

    test('calculatePerHeadShare divides interest by heads', () {
      final share = InterestCalculator.calculatePerHeadShare(10000.0, 10);
      expect(share, 1000.0);
    });

    test('calculatePerHeadShare returns 0 for 0 heads', () {
      final share = InterestCalculator.calculatePerHeadShare(10000.0, 0);
      expect(share, 0.0);
    });

    test('calculateRemainingBalance returns correct balance', () {
      final balance = InterestCalculator.calculateRemainingBalance(testLoan, testRepayments);
      expect(balance, 4000.0);
    });

    test('calculateRemainingBalance returns 0 when fully repaid', () {
      final fullRepayments = [
        ...testRepayments,
        Repayment(
          id: 'rep3',
          loanId: 'loan1',
          amountPaid: 4000.0,
          date: DateTime.now(),
        ),
      ];
      final balance = InterestCalculator.calculateRemainingBalance(testLoan, fullRepayments);
      expect(balance, 0.0);
    });

    test('calculateRepaymentProgress returns correct percentage', () {
      final progress = InterestCalculator.calculateRepaymentProgress(testLoan, testRepayments);
      expect(progress, closeTo(0.636, 0.001));
    });

    test('calculateRepaymentProgress returns 0 for 0 total due', () {
      final zeroLoan = Loan(
        id: 'loan0',
        memberId: 'member1',
        principal: 0.0,
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
          amountPaid: 4000.0,
          date: DateTime.now(),
        ),
      ];
      expect(InterestCalculator.isLoanFullyRepaid(testLoan, fullRepayments), true);
    });

    test('isLoanFullyRepaid returns false when total repaid < total due', () {
      expect(InterestCalculator.isLoanFullyRepaid(testLoan, testRepayments), false);
    });
  });
}