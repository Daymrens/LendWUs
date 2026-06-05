import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sinking_fund_app/data/models/loan.dart';
import 'package:sinking_fund_app/data/models/user.dart';
import 'package:sinking_fund_app/data/models/member.dart';
import 'package:sinking_fund_app/data/models/contribution.dart';
import 'package:sinking_fund_app/data/models/payment_request.dart';

void main() {
  group('Loan model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final issued = DateTime.utc(2026, 1, 15);
      final due = DateTime.utc(2026, 4, 15);
      final original = Loan(
        id: 'loan-1',
        memberId: 'member-1',
        principal: 5000.0,
        interestRate: 0.05,
        issuedDate: issued,
        dueDate: due,
        isFullyRepaid: false,
      );

      final restored = Loan.fromMap(original.toMap());

      expect(restored.id, 'loan-1');
      expect(restored.memberId, 'member-1');
      expect(restored.principal, 5000.0);
      expect(restored.interestRate, 0.05);
      expect(restored.issuedDate, issued);
      expect(restored.dueDate, due);
      expect(restored.isFullyRepaid, false);
    });

    test('fromMap tolerates missing optional fields', () {
      final loan = Loan.fromMap({
        'memberId': 'm1',
        'principal': 100,
        'interestRate': 0.1,
        'issuedDate': '2026-01-01T00:00:00.000Z',
        'dueDate': '2026-02-01T00:00:00.000Z',
      });

      expect(loan.id, isNull);
      expect(loan.isFullyRepaid, false);
    });

    test('fromMap accepts int and double for numeric fields', () {
      final loan = Loan.fromMap({
        'memberId': 'm1',
        'principal': 1000,
        'interestRate': 0,
        'issuedDate': DateTime(2026, 1, 1),
        'dueDate': DateTime(2026, 2, 1),
        'isFullyRepaid': 1,
      });

      expect(loan.principal, 1000.0);
      expect(loan.interestRate, 0.0);
      expect(loan.isFullyRepaid, true);
    });
  });

  group('User model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final created = DateTime.utc(2026, 1, 1);
      final original = User(
        id: 'user-1',
        username: 'admin',
        email: 'admin@example.com',
        role: UserRole.admin,
        memberId: 'm-1',
        photoUrl: 'https://example.com/photo.png',
        fcmToken: 'token-abc',
        createdAt: created,
      );

      final restored = User.fromMap(original.toMap());

      expect(restored.id, 'user-1');
      expect(restored.username, 'admin');
      expect(restored.email, 'admin@example.com');
      expect(restored.role, UserRole.admin);
      expect(restored.memberId, 'm-1');
      expect(restored.photoUrl, 'https://example.com/photo.png');
      expect(restored.fcmToken, 'token-abc');
      expect(restored.createdAt, created);
    });

    test('fromMap defaults to member role on unknown', () {
      final user = User.fromMap({
        'username': 'x',
        'email': 'x@y.com',
        'role': 'unknown',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(user.role, UserRole.member);
    });

    test('role case-insensitive parsing', () {
      final user = User.fromMap({
        'username': 'x',
        'email': 'x@y.com',
        'role': 'ADMIN',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(user.role, UserRole.admin);
    });
  });

  group('Member model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final joined = DateTime.utc(2026, 1, 1);
      final original = Member(
        id: 'm-1',
        memberId: 'LWS000001',
        name: 'Alice',
        headsCount: 3,
        amountPerHead: 200,
        totalRequired: 600,
        balance: 150,
        avatarPath: '/avatars/alice.png',
        joinedAt: joined,
        isActive: true,
        linkedEmail: 'alice@example.com',
      );

      final restored = Member.fromMap(original.toMap());

      expect(restored.id, 'm-1');
      expect(restored.memberId, 'LWS000001');
      expect(restored.name, 'Alice');
      expect(restored.headsCount, 3);
      expect(restored.amountPerHead, 200);
      expect(restored.totalRequired, 600);
      expect(restored.balance, 150);
      expect(restored.avatarPath, '/avatars/alice.png');
      expect(restored.joinedAt, joined);
      expect(restored.isActive, true);
      expect(restored.linkedEmail, 'alice@example.com');
      expect(restored.displayId, 'LWS000001');
    });

    test('fromMap defaults headsCount to 1 when missing', () {
      final m = Member.fromMap({
        'name': 'Bob',
        'amountPerHead': 100,
        'totalRequired': 100,
        'joinedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(m.headsCount, 1);
    });

    test('fromMap defaults isActive to false (since missing != true)', () {
      final m = Member.fromMap({
        'name': 'Bob',
        'headsCount': 1,
        'amountPerHead': 100,
        'totalRequired': 100,
        'joinedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(m.isActive, false);
    });

    test('toMap omits null linkedEmail, avatarPath, and memberId (Firestore rejects undefined)', () {
      final m = Member(
        name: 'Alice',
        headsCount: 1,
        amountPerHead: 100,
        totalRequired: 100,
        joinedAt: DateTime(2026, 1, 1),
      );
      final map = m.toMap();
      expect(map.containsKey('linkedEmail'), false);
      expect(map.containsKey('avatarPath'), false);
      expect(map.containsKey('memberId'), false);
    });

    test('toMap includes linkedEmail when set', () {
      final m = Member(
        name: 'Alice',
        headsCount: 1,
        amountPerHead: 100,
        totalRequired: 100,
        linkedEmail: 'alice@example.com',
        joinedAt: DateTime(2026, 1, 1),
      );
      final map = m.toMap();
      expect(map['linkedEmail'], 'alice@example.com');
    });

    test('toMap includes memberId when set', () {
      final m = Member(
        memberId: 'LWS000042',
        name: 'Alice',
        headsCount: 1,
        amountPerHead: 100,
        totalRequired: 100,
        joinedAt: DateTime(2026, 1, 1),
      );
      final map = m.toMap();
      expect(map['memberId'], 'LWS000042');
    });

    test('displayId falls back to id when memberId is missing', () {
      final m = Member(
        id: 'firestore-doc-id',
        name: 'Alice',
        headsCount: 1,
        amountPerHead: 100,
        totalRequired: 100,
        joinedAt: DateTime(2026, 1, 1),
      );
      expect(m.displayId, 'firestore-doc-id');
    });

    test('displayId prefers memberId over id', () {
      final m = Member(
        id: 'firestore-doc-id',
        memberId: 'LWS000007',
        name: 'Alice',
        headsCount: 1,
        amountPerHead: 100,
        totalRequired: 100,
        joinedAt: DateTime(2026, 1, 1),
      );
      expect(m.displayId, 'LWS000007');
    });
  });

  group('PaymentRequest model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final requested = DateTime.utc(2026, 2, 1);
      final approved = DateTime.utc(2026, 2, 2);
      final original = PaymentRequest(
        id: 'pr-1',
        memberId: 'm-1',
        loanId: 'loan-1',
        type: PaymentType.loan,
        amount: 1500,
        receiptPath: '/receipts/r1.png',
        status: PaymentStatus.approved,
        requestDate: requested,
        approvedDate: approved,
        approvedBy: 'admin',
        notes: 'partial',
        rejectReason: null,
      );

      final restored = PaymentRequest.fromMap(original.toMap());

      expect(restored.id, 'pr-1');
      expect(restored.memberId, 'm-1');
      expect(restored.loanId, 'loan-1');
      expect(restored.type, PaymentType.loan);
      expect(restored.amount, 1500);
      expect(restored.receiptPath, '/receipts/r1.png');
      expect(restored.status, PaymentStatus.approved);
      expect(restored.requestDate, requested);
      expect(restored.approvedDate, approved);
      expect(restored.approvedBy, 'admin');
      expect(restored.notes, 'partial');
      expect(restored.rejectReason, isNull);
    });

    test('fromMap defaults status to pending when unknown', () {
      final r = PaymentRequest.fromMap({
        'memberId': 'm-1',
        'type': 'contribution',
        'amount': 100,
        'status': 'weird',
        'requestDate': '2026-01-01T00:00:00.000Z',
      });

      expect(r.status, PaymentStatus.pending);
    });

    test('fromMap defaults type to contribution when unknown', () {
      final r = PaymentRequest.fromMap({
        'memberId': 'm-1',
        'type': 'unknown',
        'amount': 100,
        'status': 'pending',
        'requestDate': '2026-01-01T00:00:00.000Z',
      });

      expect(r.type, PaymentType.contribution);
    });

    test('approvedDate null when not provided', () {
      final r = PaymentRequest.fromMap({
        'memberId': 'm-1',
        'type': 'contribution',
        'amount': 100,
        'status': 'pending',
        'requestDate': '2026-01-01T00:00:00.000Z',
      });

      expect(r.approvedDate, isNull);
    });
  });

  group('Contribution fromMap with Timestamp', () {
    test('date as Firestore Timestamp parses without casting error', () {
      final ts = Timestamp.fromDate(DateTime(2026, 6, 15, 10, 30));
      final c = Contribution.fromMap({
        'memberId': 'm-1',
        'amount': 500,
        'date': ts,
        'month': 6,
        'year': 2026,
      });

      expect(c.date, DateTime(2026, 6, 15, 10, 30));
    });

    test('date as ISO string still parses', () {
      final c = Contribution.fromMap({
        'memberId': 'm-1',
        'amount': 500,
        'date': '2026-06-15T10:30:00.000Z',
        'month': 6,
        'year': 2026,
      });

      expect(c.date.toUtc(), DateTime.utc(2026, 6, 15, 10, 30));
    });
  });
}
