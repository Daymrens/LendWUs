import 'package:flutter_test/flutter_test.dart';
import 'package:sinking_fund_app/data/models/contribution.dart';
import 'package:sinking_fund_app/data/models/loan.dart';
import 'package:sinking_fund_app/data/models/repayment.dart';
import 'package:sinking_fund_app/data/models/fund_summary.dart';

void main() {
  group('FundSummary.compute', () {
    test('empty inputs produce all zeros', () {
      final summary = FundSummary.compute(
        contributions: const [],
        loans: const [],
        repayments: const [],
      );
      expect(summary.totalContributions, 0);
      expect(summary.totalLoansIssued, 0);
      expect(summary.totalRepayments, 0);
      expect(summary.totalInterestEarned, 0);
      expect(summary.fundBalance, 0);
      expect(summary.availableToLoan, 0);
    });

    test('contributions only: fund balance = contributions, available = same', () {
      final contribs = [
        Contribution(memberId: 'm1', amount: 500, date: DateTime(2026, 1, 15), month: 1, year: 2026),
        Contribution(memberId: 'm2', amount: 500, date: DateTime(2026, 1, 16), month: 1, year: 2026),
      ];
      final summary = FundSummary.compute(contributions: contribs, loans: const [], repayments: const []);
      expect(summary.totalContributions, 1000);
      expect(summary.fundBalance, 1000);
      expect(summary.availableToLoan, 1000);
    });

    test('outstanding loan reduces available but not fund balance', () {
      final contribs = [Contribution(memberId: 'm1', amount: 1000, date: DateTime(2026, 1, 15), month: 1, year: 2026)];
      final loans = [
        Loan(
          id: 'l1',
          memberId: 'm1',
          principal: 500,
          interestRate: 0.1,
          issuedDate: DateTime(2026, 1, 16),
          dueDate: DateTime(2026, 2, 16),
          isFullyRepaid: false,
        ),
      ];
      final summary = FundSummary.compute(contributions: contribs, loans: loans, repayments: const []);
      expect(summary.fundBalance, 500);
      expect(summary.totalLoansIssued, 500);
      // outstanding (500*1.1=550) > fund balance (500) → negative available
      expect(summary.availableToLoan, -50);
    });

    test('fully repaid loan with interest: interest counts as fund balance', () {
      final contribs = [Contribution(memberId: 'm1', amount: 1000, date: DateTime(2026, 1, 15), month: 1, year: 2026)];
      final loans = [
        Loan(
          id: 'l1',
          memberId: 'm1',
          principal: 500,
          interestRate: 0.1,
          issuedDate: DateTime(2026, 1, 16),
          dueDate: DateTime(2026, 2, 16),
          isFullyRepaid: true,
        ),
      ];
      final repay = [
        Repayment(loanId: 'l1', amountPaid: 550, date: DateTime(2026, 2, 15)),
      ];
      final summary = FundSummary.compute(contributions: contribs, loans: loans, repayments: repay);
      expect(summary.fundBalance, 1050);
      expect(summary.totalRepayments, 550);
      // "Interest" here is defined as amount paid above principal (not the rate).
      expect(summary.totalInterestEarned, 50);
      expect(summary.availableToLoan, 1050);
    });

    test('partial repayment: outstanding subtracted from available', () {
      final contribs = [Contribution(memberId: 'm1', amount: 1000, date: DateTime(2026, 1, 15), month: 1, year: 2026)];
      final loans = [
        Loan(
          id: 'l1',
          memberId: 'm1',
          principal: 500,
          interestRate: 0.1,
          issuedDate: DateTime(2026, 1, 16),
          dueDate: DateTime(2026, 2, 16),
          isFullyRepaid: false,
        ),
      ];
      final repay = [
        Repayment(loanId: 'l1', amountPaid: 200, date: DateTime(2026, 2, 1)),
      ];
      final summary = FundSummary.compute(contributions: contribs, loans: loans, repayments: repay);
      // Fund balance = 1000 - 500 + 200 = 700
      expect(summary.fundBalance, 700);
      // Outstanding = 500 * 1.1 - 200 = 350
      // Available = 700 - 350 = 350
      expect(summary.availableToLoan, 350);
    });

    test('overpayment on loan: counts as interest above principal', () {
      final contribs = [Contribution(memberId: 'm1', amount: 1000, date: DateTime(2026, 1, 15), month: 1, year: 2026)];
      final loans = [
        Loan(
          id: 'l1',
          memberId: 'm1',
          principal: 500,
          interestRate: 0.1,
          issuedDate: DateTime(2026, 1, 16),
          dueDate: DateTime(2026, 2, 16),
          isFullyRepaid: false,
        ),
      ];
      final repay = [
        Repayment(loanId: 'l1', amountPaid: 600, date: DateTime(2026, 2, 15)),
      ];
      final summary = FundSummary.compute(contributions: contribs, loans: loans, repayments: repay);
      // Interest = overpayment above principal (600 - 500 = 100), not the rate
      expect(summary.totalInterestEarned, 100);
    });
  });
}
