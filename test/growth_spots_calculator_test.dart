import 'package:flutter_test/flutter_test.dart';
import 'package:sinking_fund_app/core/utils/growth_spots_calculator.dart';
import 'package:sinking_fund_app/data/models/contribution.dart';
import 'package:sinking_fund_app/data/models/loan.dart';
import 'package:sinking_fund_app/data/models/repayment.dart';

void main() {
  group('GrowthSpotsCalculator.compute', () {
    test('empty inputs produce spots for each day of the month at 0', () {
      final spots = GrowthSpotsCalculator.compute([], [], [], 2026, 6);
      expect(spots.length, 30); // June has 30 days
      expect(spots[0].x, 1.0);
      expect(spots[0].y, 0);
      expect(spots[29].x, 30.0);
      expect(spots[29].y, 0);
    });

    test('contributions increase running balance day-by-day', () {
      final contribs = [
        Contribution(memberId: 'm1', amount: 500, date: DateTime(2026, 6, 5), month: 6, year: 2026),
        Contribution(memberId: 'm1', amount: 300, date: DateTime(2026, 6, 10), month: 6, year: 2026),
      ];
      final spots = GrowthSpotsCalculator.compute(contribs, [], [], 2026, 6);
      expect(spots.length, 30); // June has 30 days
      expect(spots[0].y, 0);   // day 1: no contribs yet
      expect(spots[4].y, 500); // day 5: after first contrib
      expect(spots[9].y, 800); // day 10: after second contrib
    });

    test('loans decrease running balance', () {
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 1000, interestRate: 0.1,
          issuedDate: DateTime(2026, 6, 10), dueDate: DateTime(2026, 7, 10)),
      ];
      final spots = GrowthSpotsCalculator.compute([], loans, [], 2026, 6);
      expect(spots[9].y, -1000); // day 10: after loan issued
    });

    test('repayments increase running balance', () {
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 1000, interestRate: 0.1,
          issuedDate: DateTime(2026, 5, 1), dueDate: DateTime(2026, 7, 1)),
      ];
      final repayments = [
        Repayment(loanId: 'l1', amountPaid: 500, date: DateTime(2026, 6, 15)),
      ];
      final spots = GrowthSpotsCalculator.compute([], loans, repayments, 2026, 6);
      expect(spots[0].y, -1000); // day 1: loan from prior month
      expect(spots[14].y, -500); // day 15: after repayment
    });

    test('full workflow with all transaction types', () {
      final contribs = [
        Contribution(memberId: 'm1', amount: 2000, date: DateTime(2026, 6, 1), month: 6, year: 2026),
      ];
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 1500, interestRate: 0.1,
          issuedDate: DateTime(2026, 6, 5), dueDate: DateTime(2026, 7, 5)),
      ];
      final repayments = [
        Repayment(loanId: 'l1', amountPaid: 800, date: DateTime(2026, 6, 20)),
      ];
      final spots = GrowthSpotsCalculator.compute(contribs, loans, repayments, 2026, 6);
      expect(spots[0].y, 2000);  // day 1: contribution
      expect(spots[4].y, 500);  // day 5: 2000 - 1500
      expect(spots[19].y, 1300); // day 20: 500 + 800
      expect(spots[29].y, 1300); // day 30: unchanged after repayment
    });

    test('handles contributions, loans, repayments from other months', () {
      final contribs = [
        Contribution(memberId: 'm1', amount: 1000, date: DateTime(2026, 5, 1), month: 5, year: 2026),
        Contribution(memberId: 'm1', amount: 500, date: DateTime(2026, 6, 15), month: 6, year: 2026),
      ];
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 300, interestRate: 0.1,
          issuedDate: DateTime(2026, 5, 10), dueDate: DateTime(2026, 6, 10)),
        Loan(id: 'l2', memberId: 'm1', principal: 200, interestRate: 0.1,
          issuedDate: DateTime(2026, 6, 20), dueDate: DateTime(2026, 7, 20)),
      ];
      final repayments = [
        Repayment(loanId: 'l1', amountPaid: 330, date: DateTime(2026, 6, 5)),
      ];
      final spots = GrowthSpotsCalculator.compute(contribs, loans, repayments, 2026, 6);
      // Carry-in: 1000 (May contrib) - 300 (loan issued in May) = 700
      expect(spots[0].y, 700);
      // Day 5: +330 repayment (loan l1 fully repaid with 30 interest)
      expect(spots[4].y, 1030);
      // Day 15: +500 contrib → 1030 + 500
      expect(spots[14].y, 1530);
      // Day 20: -200 loan → 1530 - 200
      expect(spots[19].y, 1330);
    });

    test('handles leap year February', () {
      final contribs = [
        Contribution(memberId: 'm1', amount: 100, date: DateTime(2024, 2, 29), month: 2, year: 2024),
      ];
      final spots = GrowthSpotsCalculator.compute(contribs, [], [], 2024, 2);
      expect(spots.length, 29); // Feb 2024 has 29 days
      expect(spots[28].y, 100); // day 29
    });

    test('handles 31-day month', () {
      final contribs = [
        Contribution(memberId: 'm1', amount: 100, date: DateTime(2026, 1, 31), month: 1, year: 2026),
      ];
      final spots = GrowthSpotsCalculator.compute(contribs, [], [], 2026, 1);
      expect(spots.length, 31); // January has 31 days
      expect(spots[30].y, 100); // day 31
    });
  });

  group('GrowthSpotsCalculator edge cases', () {
    test('zero principal loans are handled correctly', () {
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 0, interestRate: 0.1,
          issuedDate: DateTime(2026, 6, 15), dueDate: DateTime(2026, 7, 15)),
      ];
      final spots = GrowthSpotsCalculator.compute([], loans, [], 2026, 6);
      expect(spots[14].y, 0); // day 15: no change for zero-principal loan
    });

    test('multiple transactions on same day are cumulative', () {
      final contribs = [
        Contribution(memberId: 'm1', amount: 500, date: DateTime(2026, 6, 10), month: 6, year: 2026),
        Contribution(memberId: 'm2', amount: 300, date: DateTime(2026, 6, 10), month: 6, year: 2026),
      ];
      final spots = GrowthSpotsCalculator.compute(contribs, [], [], 2026, 6);
      expect(spots[9].y, 800); // day 10: 500 + 300
    });
  });
}
