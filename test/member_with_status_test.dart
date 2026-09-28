import 'package:flutter_test/flutter_test.dart';
import 'package:sinking_fund_app/data/models/member.dart';
import 'package:sinking_fund_app/data/models/contribution.dart';
import 'package:sinking_fund_app/data/models/member_with_status.dart';

void main() {
  Member makeMember({
    required String id,
    String name = 'Test Member',
    int heads = 1,
    int amountPerHead = 20000,
    int totalRequired = 20000,
    int balance = 0,
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
    required int amount,
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
        id: 'm1',
        heads: 3,
        amountPerHead: 50000,
        totalRequired: 150000,
      );
      final status = MemberWithStatus.of(m, const [], 6, 2026);
      expect(status.requiredAmount, 150000);
    });

    test('falls back to heads*amountPerHead when totalRequired is 0', () {
      final m = makeMember(
        id: 'm1',
        heads: 4,
        amountPerHead: 25000,
        totalRequired: 0,
      );
      final status = MemberWithStatus.of(m, const [], 6, 2026);
      expect(status.requiredAmount, 100000);
    });

    test('unpaid member: status Pending, color orange', () {
      final m = makeMember(id: 'm1');
      final status = MemberWithStatus.of(m, const [], 6, 2026);
      expect(status.amountPaid, 0);
      expect(status.progress, 0);
      expect(status.paymentStatus, 'Pending');
      expect(status.statusColor, 'orange');
    });

    test('partial payment: shows percentage', () {
      final m = makeMember(id: 'm1', totalRequired: 50000, amountPerHead: 50000);
      final contribs = [makeContrib(memberId: 'm1', amount: 25000, month: 6, year: 2026)];
      final status = MemberWithStatus.of(m, contribs, 6, 2026);
      expect(status.amountPaid, 25000);
      expect(status.progress, 0.5);
      expect(status.paymentStatus, '50%');
      expect(status.statusColor, 'blue');
    });

    test('full payment: status Paid, color green, progress capped at 1.0', () {
      final m = makeMember(id: 'm1', totalRequired: 60000, amountPerHead: 60000);
      final contribs = [
        makeContrib(memberId: 'm1', amount: 30000, month: 6, year: 2026),
        makeContrib(memberId: 'm1', amount: 30000, month: 6, year: 2026),
      ];
      final status = MemberWithStatus.of(m, contribs, 6, 2026);
      expect(status.amountPaid, 60000);
      expect(status.progress, 1.0);
      expect(status.paymentStatus, 'Paid');
      expect(status.statusColor, 'green');
    });

    test('overpayment: progress still capped at 1.0', () {
      final m = makeMember(id: 'm1', totalRequired: 50000);
      final contribs = [makeContrib(memberId: 'm1', amount: 70000, month: 6, year: 2026)];
      final status = MemberWithStatus.of(m, contribs, 6, 2026);
      expect(status.amountPaid, 70000);
      expect(status.progress, 1.0);
      expect(status.remaining, -20000);
      expect(status.paymentStatus, 'Paid');
    });

    test('ignores contributions from other months', () {
      final m = makeMember(id: 'm1');
      final contribs = [makeContrib(memberId: 'm1', amount: 50000, month: 5, year: 2026)];
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
      final m = makeMember(id: 'm1', totalRequired: 0, amountPerHead: 0);
      final status = MemberWithStatus.of(m, const [], 6, 2026);
      expect(status.progress, 0);
      expect(status.paymentStatus, 'Pending');
    });
  });
}
