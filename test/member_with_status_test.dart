import 'package:flutter_test/flutter_test.dart';
import 'package:sinking_fund_app/data/models/member.dart';
import 'package:sinking_fund_app/data/models/contribution.dart';
import 'package:sinking_fund_app/data/models/member_with_status.dart';

void main() {
  Member makeMember({
    String id = 'm1',
    String name = 'Alice',
    int heads = 1,
    double amountPerHead = 500,
    double totalRequired = 500,
    double balance = 0,
  }) {
    return Member(
      id: id,
      name: name,
      headsCount: heads,
      amountPerHead: amountPerHead,
      totalRequired: totalRequired,
      balance: balance,
      joinedAt: DateTime(2026, 1, 1),
    );
  }

  Contribution makeContrib({
    required String memberId,
    required double amount,
    required int month,
    required int year,
  }) {
    return Contribution(
      memberId: memberId,
      amount: amount,
      date: DateTime(year, month, 15),
      month: month,
      year: year,
    );
  }

  group('MemberWithStatus.of', () {
    test('prefers stored totalRequired over heads*amountPerHead multiplication', () {
      final m = makeMember(
        heads: 3,
        amountPerHead: 500,
        totalRequired: 1500,
      );
      final status = MemberWithStatus.of(m, const [], 6, 2026);
      expect(status.requiredAmount, 1500);
    });

    test('falls back to heads*amountPerHead when totalRequired is 0', () {
      final m = makeMember(
        heads: 4,
        amountPerHead: 250,
        totalRequired: 0,
      );
      final status = MemberWithStatus.of(m, const [], 6, 2026);
      expect(status.requiredAmount, 1000);
    });

    test('unpaid member: status Pending, color orange', () {
      final m = makeMember();
      final status = MemberWithStatus.of(m, const [], 6, 2026);
      expect(status.amountPaid, 0);
      expect(status.progress, 0);
      expect(status.paymentStatus, 'Pending');
      expect(status.statusColor, 'orange');
    });

    test('partial payment: shows percentage', () {
      final m = makeMember();
      final contribs = [makeContrib(memberId: 'm1', amount: 250, month: 6, year: 2026)];
      final status = MemberWithStatus.of(m, contribs, 6, 2026);
      expect(status.amountPaid, 250);
      expect(status.progress, 0.5);
      expect(status.paymentStatus, '50%');
      expect(status.statusColor, 'blue');
    });

    test('full payment: status Paid, color green, progress capped at 1.0', () {
      final m = makeMember();
      final contribs = [
        makeContrib(memberId: 'm1', amount: 300, month: 6, year: 2026),
        makeContrib(memberId: 'm1', amount: 300, month: 6, year: 2026),
      ];
      final status = MemberWithStatus.of(m, contribs, 6, 2026);
      expect(status.amountPaid, 600);
      expect(status.progress, 1.0);
      expect(status.paymentStatus, 'Paid');
      expect(status.statusColor, 'green');
    });

    test('overpayment: progress still capped at 1.0', () {
      final m = makeMember(totalRequired: 500);
      final contribs = [makeContrib(memberId: 'm1', amount: 700, month: 6, year: 2026)];
      final status = MemberWithStatus.of(m, contribs, 6, 2026);
      expect(status.amountPaid, 700);
      expect(status.progress, 1.0);
      expect(status.remaining, -200);
      expect(status.paymentStatus, 'Paid');
    });

    test('ignores contributions from other months', () {
      final m = makeMember();
      final contribs = [makeContrib(memberId: 'm1', amount: 500, month: 5, year: 2026)];
      final status = MemberWithStatus.of(m, contribs, 6, 2026);
      expect(status.amountPaid, 0);
    });

    test('ignores contributions from other members', () {
      final m = makeMember(id: 'm1');
      final contribs = [makeContrib(memberId: 'm2', amount: 500, month: 6, year: 2026)];
      final status = MemberWithStatus.of(m, contribs, 6, 2026);
      expect(status.amountPaid, 0);
    });

    test('handles zero required (avoids divide-by-zero)', () {
      final m = makeMember(totalRequired: 0, amountPerHead: 0);
      final status = MemberWithStatus.of(m, const [], 6, 2026);
      expect(status.progress, 0);
      expect(status.paymentStatus, 'Pending');
    });
  });
}
