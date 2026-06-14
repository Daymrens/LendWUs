import 'package:flutter_test/flutter_test.dart';
import 'package:sinking_fund_app/data/models/contribution.dart';
import 'package:sinking_fund_app/data/models/loan.dart';
import 'package:sinking_fund_app/data/models/repayment.dart';
import 'package:sinking_fund_app/data/models/monthly_report.dart';

void main() {
  group('MonthlyReport.compute', () {
    test('empty inputs produce all zeros', () {
      final report = MonthlyReport.compute(6, 2026, [], [], [], 0);
      expect(report.month, 6);
      expect(report.year, 2026);
      expect(report.totalContribution, 0);
      expect(report.loansIssued, 0);
      expect(report.interestGained, 0);
      expect(report.endingBalance, 0);
    });

    test('filters contributions by month/year', () {
      final contribs = [
        Contribution(memberId: 'm1', amount: 300, date: DateTime(2026, 6, 5), month: 6, year: 2026),
        Contribution(memberId: 'm2', amount: 200, date: DateTime(2026, 6, 10), month: 6, year: 2026),
        Contribution(memberId: 'm3', amount: 100, date: DateTime(2026, 5, 15), month: 5, year: 2026),
      ];
      final report = MonthlyReport.compute(6, 2026, contribs, [], [], 600);
      expect(report.totalContribution, 500);
      expect(report.loansIssued, 0);
      expect(report.interestGained, 0);
      expect(report.endingBalance, 600);
    });

    test('filters loans by month/year', () {
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 1000, interestRate: 0.1, issuedDate: DateTime(2026, 6, 1), dueDate: DateTime(2026, 7, 1)),
        Loan(id: 'l2', memberId: 'm2', principal: 2000, interestRate: 0.1, issuedDate: DateTime(2026, 5, 1), dueDate: DateTime(2026, 6, 1)),
      ];
      final report = MonthlyReport.compute(6, 2026, [], loans, [], 0);
      expect(report.loansIssued, 1000);
    });

    test('interest gained from repayments in the month', () {
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 1000, interestRate: 0.1, issuedDate: DateTime(2026, 5, 1), dueDate: DateTime(2026, 7, 1)),
      ];
      final repayments = [
        Repayment(loanId: 'l1', amountPaid: 1100, date: DateTime(2026, 6, 15)),
      ];
      final report = MonthlyReport.compute(6, 2026, [], loans, repayments, 100);
      expect(report.interestGained, 100);
    });

    test('no interest if repayment does not exceed principal', () {
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 1000, interestRate: 0.1, issuedDate: DateTime(2026, 5, 1), dueDate: DateTime(2026, 7, 1)),
      ];
      final repayments = [
        Repayment(loanId: 'l1', amountPaid: 500, date: DateTime(2026, 6, 15)),
      ];
      final report = MonthlyReport.compute(6, 2026, [], loans, repayments, 0);
      expect(report.interestGained, 0);
    });

    test('interest from partial repayment that exceeds principal', () {
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 1000, interestRate: 0.1, issuedDate: DateTime(2026, 5, 1), dueDate: DateTime(2026, 7, 1)),
      ];
      final repayments = [
        Repayment(loanId: 'l1', amountPaid: 400, date: DateTime(2026, 6, 1)),
        Repayment(loanId: 'l1', amountPaid: 700, date: DateTime(2026, 6, 15)),
      ];
      final report = MonthlyReport.compute(6, 2026, [], loans, repayments, 100);
      expect(report.interestGained, 100);
    });

    test('ignores repayments from other months', () {
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 1000, interestRate: 0.1, issuedDate: DateTime(2026, 5, 1), dueDate: DateTime(2026, 7, 1)),
      ];
      final repayments = [
        Repayment(loanId: 'l1', amountPaid: 1100, date: DateTime(2026, 5, 15)),
      ];
      final report = MonthlyReport.compute(6, 2026, [], loans, repayments, 0);
      expect(report.interestGained, 0);
    });

    test('multiple loans with interest in same month', () {
      final loans = [
        Loan(id: 'l1', memberId: 'm1', principal: 1000, interestRate: 0.1, issuedDate: DateTime(2026, 5, 1), dueDate: DateTime(2026, 7, 1)),
        Loan(id: 'l2', memberId: 'm2', principal: 2000, interestRate: 0.05, issuedDate: DateTime(2026, 5, 15), dueDate: DateTime(2026, 7, 15)),
      ];
      final repayments = [
        Repayment(loanId: 'l1', amountPaid: 1100, date: DateTime(2026, 6, 1)),
        Repayment(loanId: 'l2', amountPaid: 2100, date: DateTime(2026, 6, 10)),
      ];
      final report = MonthlyReport.compute(6, 2026, [], loans, repayments, 0);
      expect(report.interestGained, 200);
    });

    test('passes through endingBalance unchanged', () {
      final report = MonthlyReport.compute(6, 2026, [], [], [], 12345.67);
      expect(report.endingBalance, 12345.67);
    });
  });
}
