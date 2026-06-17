import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sinking_fund_app/data/models/loan.dart';
import 'package:sinking_fund_app/data/models/user.dart';
import 'package:sinking_fund_app/data/models/member.dart';
import 'package:sinking_fund_app/data/models/contribution.dart';
import 'package:sinking_fund_app/data/models/payment_request.dart';
import 'package:sinking_fund_app/data/models/repayment.dart';
import 'package:sinking_fund_app/data/models/loan_request.dart';
import 'package:sinking_fund_app/data/models/head_change_request.dart';
import 'package:sinking_fund_app/data/models/activity_log.dart';
import 'package:sinking_fund_app/data/models/notification_item.dart';
import 'package:sinking_fund_app/data/models/app_settings.dart';
import 'package:sinking_fund_app/data/models/returns_info.dart';

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

    test('fromMap defaults isActive to true when field is missing', () {
      final m = Member.fromMap({
        'name': 'Bob',
        'headsCount': 1,
        'amountPerHead': 100,
        'totalRequired': 100,
        'joinedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(m.isActive, true);
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
      expect(restored.receiptPath, isNull);
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

    test('toMap then fromMap round-trip preserves all fields', () {
      final date = DateTime.utc(2026, 6, 15);
      final original = Contribution(
        id: 'c-1',
        memberId: 'm-1',
        amount: 500.0,
        date: date,
        month: 6,
        year: 2026,
        notes: 'first payment',
        createdBy: 'admin',
      );
      final restored = Contribution.fromMap(original.toMap());
      expect(restored.id, 'c-1');
      expect(restored.memberId, 'm-1');
      expect(restored.amount, 500.0);
      expect(restored.date, date);
      expect(restored.month, 6);
      expect(restored.year, 2026);
      expect(restored.notes, 'first payment');
      expect(restored.createdBy, 'admin');
    });

    test('fromMap defaults month/year to now when missing', () {
      final c = Contribution.fromMap({
        'memberId': 'm-1',
        'amount': 100,
        'date': '2026-06-15T00:00:00.000Z',
      });
      expect(c.month, DateTime.now().month);
      expect(c.year, DateTime.now().year);
    });
  });

  group('Repayment model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final date = DateTime.utc(2026, 2, 15);
      final original = Repayment(
        id: 'rep-1',
        loanId: 'loan-1',
        amountPaid: 550.0,
        date: date,
      );
      final restored = Repayment.fromMap(original.toMap());
      expect(restored.id, 'rep-1');
      expect(restored.loanId, 'loan-1');
      expect(restored.amountPaid, 550.0);
      expect(restored.date, date);
    });

    test('fromMap tolerates missing optional fields', () {
      final r = Repayment.fromMap({
        'loanId': 'loan-1',
        'amountPaid': 200,
        'date': '2026-02-01T00:00:00.000Z',
      });
      expect(r.id, isNull);
      expect(r.loanId, 'loan-1');
      expect(r.amountPaid, 200.0);
    });

    test('fromMap accepts int for amountPaid', () {
      final r = Repayment.fromMap({
        'loanId': 'loan-1',
        'amountPaid': 500,
        'date': DateTime(2026, 2, 1),
      });
      expect(r.amountPaid, 500.0);
    });
  });

  group('LoanRequest model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final due = DateTime.utc(2026, 3, 1);
      final requested = DateTime.utc(2026, 2, 1);
      final processed = DateTime.utc(2026, 2, 2);
      final original = LoanRequest(
        id: 'lr-1',
        memberId: 'm-1',
        memberName: 'Alice',
        amount: 5000.0,
        interestRate: 5.0,
        dueDate: due,
        status: LoanRequestStatus.approved,
        requestedAt: requested,
        processedAt: processed,
        notes: 'urgent',
        loanId: 'loan-1',
      );
      final restored = LoanRequest.fromMap(original.toMap());
      expect(restored.id, 'lr-1');
      expect(restored.memberId, 'm-1');
      expect(restored.memberName, 'Alice');
      expect(restored.amount, 5000.0);
      expect(restored.interestRate, 5.0);
      expect(restored.dueDate, due);
      expect(restored.status, LoanRequestStatus.approved);
      expect(restored.requestedAt, requested);
      expect(restored.processedAt, processed);
      expect(restored.notes, 'urgent');
      expect(restored.loanId, 'loan-1');
    });

    test('fromMap defaults status to pending when unknown', () {
      final r = LoanRequest.fromMap({
        'memberId': 'm-1',
        'memberName': 'Bob',
        'amount': 2000,
        'dueDate': '2026-03-01T00:00:00.000Z',
        'requestedAt': '2026-02-01T00:00:00.000Z',
        'status': 'unknown',
      });
      expect(r.status, LoanRequestStatus.pending);
    });

    test('fromMap defaults processedAt to null', () {
      final r = LoanRequest.fromMap({
        'memberId': 'm-1',
        'memberName': 'Bob',
        'amount': 2000,
        'dueDate': '2026-03-01T00:00:00.000Z',
        'requestedAt': '2026-02-01T00:00:00.000Z',
      });
      expect(r.processedAt, isNull);
      expect(r.interestRate, 0.0);
    });

    test('toMap includes null processedAt, notes, loanId as null', () {
      final r = LoanRequest(
        memberId: 'm-1',
        memberName: 'Alice',
        amount: 1000,
        dueDate: DateTime(2026, 3, 1),
        requestedAt: DateTime(2026, 2, 1),
      );
      final map = r.toMap();
      expect(map['processedAt'], isNull);
      expect(map['notes'], isNull);
      expect(map['loanId'], isNull);
    });
  });

  group('HeadChangeRequest model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final requested = DateTime.utc(2026, 3, 1);
      final processed = DateTime.utc(2026, 3, 2);
      final original = HeadChangeRequest(
        id: 'hcr-1',
        memberId: 'm-1',
        memberName: 'Alice',
        currentHeads: 1,
        requestedHeads: 3,
        reason: 'increase share',
        status: HeadChangeStatus.approved,
        requestedAt: requested,
        processedAt: processed,
        processedBy: 'admin',
        notes: 'ok',
      );
      final restored = HeadChangeRequest.fromMap(original.toMap());
      expect(restored.id, 'hcr-1');
      expect(restored.memberId, 'm-1');
      expect(restored.memberName, 'Alice');
      expect(restored.currentHeads, 1);
      expect(restored.requestedHeads, 3);
      expect(restored.reason, 'increase share');
      expect(restored.status, HeadChangeStatus.approved);
      expect(restored.requestedAt, requested);
      expect(restored.processedAt, processed);
      expect(restored.processedBy, 'admin');
      expect(restored.notes, 'ok');
    });

    test('fromMap defaults status to pending when unknown', () {
      final r = HeadChangeRequest.fromMap({
        'memberId': 'm-1',
        'memberName': 'Bob',
        'currentHeads': 1,
        'requestedHeads': 2,
        'requestedAt': '2026-03-01T00:00:00.000Z',
        'status': 'unknown',
      });
      expect(r.status, HeadChangeStatus.pending);
    });

    test('fromMap defaults currentHeads/requestedHeads to 0 when missing', () {
      final r = HeadChangeRequest.fromMap({
        'memberId': 'm-1',
        'memberName': 'Bob',
        'requestedAt': '2026-03-01T00:00:00.000Z',
      });
      expect(r.currentHeads, 0);
      expect(r.requestedHeads, 0);
    });
  });

  group('ActivityLog model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final created = DateTime.utc(2026, 6, 1);
      final original = ActivityLog(
        id: 'log-1',
        action: 'create_loan',
        entityType: 'loan',
        entityId: 'loan-1',
        performedBy: 'admin',
        performedByName: 'Admin',
        details: {'amount': 5000},
        createdAt: created,
      );
      final restored = ActivityLog.fromMap(original.toMap());
      expect(restored.id, 'log-1');
      expect(restored.action, 'create_loan');
      expect(restored.entityType, 'loan');
      expect(restored.entityId, 'loan-1');
      expect(restored.performedBy, 'admin');
      expect(restored.performedByName, 'Admin');
      expect(restored.details, {'amount': 5000});
      expect(restored.createdAt, created);
    });

    test('fromMap tolerates missing optional fields', () {
      final r = ActivityLog.fromMap({
        'action': 'test',
        'entityType': 'member',
        'createdAt': '2026-06-01T00:00:00.000Z',
      });
      expect(r.id, isNull);
      expect(r.entityId, isNull);
      expect(r.performedBy, isNull);
      expect(r.performedByName, isNull);
      expect(r.details, isNull);
    });

    test('fromMap returns null details when not a map', () {
      final r = ActivityLog.fromMap({
        'action': 'test',
        'entityType': 'member',
        'details': 'not a map',
        'createdAt': '2026-06-01T00:00:00.000Z',
      });
      expect(r.details, isNull);
    });
  });

  group('NotificationItem model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final created = DateTime.utc(2026, 6, 1);
      final original = NotificationItem(
        id: 'notif-1',
        userId: 'user-1',
        title: 'Payment Approved',
        body: 'Your payment of ₱500 has been approved.',
        type: 'payment_approved',
        data: {'amount': 500},
        read: true,
        createdAt: created,
      );
      final restored = NotificationItem.fromMap(original.toMap());
      expect(restored.id, 'notif-1');
      expect(restored.userId, 'user-1');
      expect(restored.title, 'Payment Approved');
      expect(restored.body, 'Your payment of ₱500 has been approved.');
      expect(restored.type, 'payment_approved');
      expect(restored.data, {'amount': 500});
      expect(restored.read, true);
      expect(restored.createdAt, created);
    });

    test('fromMap defaults read to false', () {
      final n = NotificationItem.fromMap({
        'userId': 'user-1',
        'title': 'Test',
        'body': 'body',
        'type': 'test',
        'createdAt': '2026-06-01T00:00:00.000Z',
      });
      expect(n.read, false);
      expect(n.id, isNull);
      expect(n.data, isNull);
    });

    test('fromMap returns null data when not a map', () {
      final n = NotificationItem.fromMap({
        'userId': 'user-1',
        'title': 'Test',
        'body': 'body',
        'type': 'test',
        'data': 'not a map',
        'createdAt': '2026-06-01T00:00:00.000Z',
      });
      expect(n.data, isNull);
    });

    test('copyWith overrides only specified fields', () {
      final original = NotificationItem(
        userId: 'user-1',
        title: 'Title',
        body: 'Body',
        type: 'type',
        createdAt: DateTime(2026, 1, 1),
      );
      final modified = original.copyWith(read: true, title: 'Updated');
      expect(modified.userId, 'user-1');
      expect(modified.title, 'Updated');
      expect(modified.read, true);
      expect(modified.body, 'Body');
    });
  });

  group('AppSettings model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final original = AppSettings(
        minPaymentPerHead: 100.0,
        maxPaymentPerHead: 1000.0,
        loanInterestPercent: 10.0,
        currencySymbol: '\u20B1',
        currencyCode: 'PHP',
        cutoffDay1: 13,
        cutoffDay2: 28,
        paymentTatHours: 24,
        adminEmails: ['admin@example.com'],
        qrAccountName: 'My Account',
        qrAccountNumber: '1234567890',
        qrImageUrl: 'https://example.com/qr.png',
        groupCode: 'LENDWUS',
        isMaintenanceMode: false,
        maintenanceMessage: '',
      );
      final restored = AppSettings.fromMap(original.toMap());
      expect(restored.minPaymentPerHead, 100.0);
      expect(restored.maxPaymentPerHead, 1000.0);
      expect(restored.loanInterestPercent, 10.0);
      expect(restored.currencySymbol, '\u20B1');
      expect(restored.currencyCode, 'PHP');
      expect(restored.cutoffDay1, 13);
      expect(restored.cutoffDay2, 28);
      expect(restored.paymentTatHours, 24);
      expect(restored.adminEmails, ['admin@example.com']);
      expect(restored.qrAccountName, 'My Account');
      expect(restored.qrAccountNumber, '1234567890');
      expect(restored.qrImageUrl, 'https://example.com/qr.png');
      expect(restored.groupCode, 'LENDWUS');
      expect(restored.isMaintenanceMode, false);
      expect(restored.maintenanceMessage, '');
    });

    test('fromMap defaults for missing fields', () {
      final s = AppSettings.fromMap({});
      expect(s.minPaymentPerHead, 0.0);
      expect(s.maxPaymentPerHead, 1000.0);
      expect(s.loanInterestPercent, 10.0);
      expect(s.currencySymbol, '\u20B1');
      expect(s.currencyCode, 'PHP');
      expect(s.cutoffDay1, 13);
      expect(s.cutoffDay2, 28);
      expect(s.paymentTatHours, 24);
      expect(s.adminEmails, []);
      expect(s.qrAccountName, '');
      expect(s.groupCode, 'LENDWUS');
      expect(s.isMaintenanceMode, false);
    });

    test('copyWith overrides only specified fields', () {
      final original = AppSettings(
        minPaymentPerHead: 50.0,
        maxPaymentPerHead: 500.0,
        loanInterestPercent: 5.0,
        currencySymbol: '\u20B1',
        currencyCode: 'PHP',
      );
      final modified = original.copyWith(maxPaymentPerHead: 1000.0, loanInterestPercent: 10.0);
      expect(modified.minPaymentPerHead, 50.0);
      expect(modified.maxPaymentPerHead, 1000.0);
      expect(modified.loanInterestPercent, 10.0);
      expect(modified.currencyCode, 'PHP');
    });
  });

  group('ReturnsInfo model', () {
    test('toMap then fromMap round-trip preserves all fields', () {
      final original = ReturnsInfo(
        totalReturns: 10000.0,
        totalHeads: 10,
        perHeadShare: 1000.0,
      );
      final restored = ReturnsInfo.fromMap(original.toMap());
      expect(restored.totalReturns, 10000.0);
      expect(restored.totalHeads, 10);
      expect(restored.perHeadShare, 1000.0);
    });

    test('fromMap defaults totalHeads to 1 when missing', () {
      final r = ReturnsInfo.fromMap({'totalReturns': 5000});
      expect(r.totalReturns, 5000.0);
      expect(r.totalHeads, 1);
      expect(r.perHeadShare, 5000.0);
    });

    test('perHeadShare is 0 when totalHeads is 0', () {
      final r = ReturnsInfo.fromMap({'totalReturns': 5000, 'totalHeads': 0});
      expect(r.perHeadShare, 0.0);
    });

    test('perHeadShare is 0 when totalReturns is 0', () {
      final r = ReturnsInfo.fromMap({'totalReturns': 0, 'totalHeads': 5});
      expect(r.perHeadShare, 0.0);
    });
  });
}
