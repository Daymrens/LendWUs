import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_request.dart';
import '../models/contribution.dart';
import '../models/repayment.dart';
import 'activity_log_repository.dart';
import 'loan_repository.dart';
import 'notification_repository.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/utils/currency_formatter.dart';

class PaymentRequestRepository {
  final ActivityLogRepository _activityLog;

  PaymentRequestRepository({ActivityLogRepository? activityLog})
      : _activityLog = activityLog ?? ActivityLogRepository();
  static const int _defaultPageSize = 100;
  Future<String> createPaymentRequest(PaymentRequest request) async {
    final docRef = await FirebaseService.firestore
        .collection('payment_requests')
        .add(request.toMap());

    final memberName = await _getMemberName(request.memberId);
    final typeLabel = request.type == PaymentType.contribution ? 'Contribution' : 'Loan Repayment';
    final amountLabel = CurrencyFormatter.format(request.amount);
    NotificationRepository.notifyAdmins(
      'New $typeLabel Request',
      '$memberName submitted a $typeLabel of $amountLabel for approval',
      type: 'payment_request_created',
    );
    NotificationRepository.notifyTreasurers(
      'New $typeLabel Request',
      '$memberName submitted a $typeLabel of $amountLabel for approval',
      type: 'payment_request_created',
    );

    return docRef.id;
  }

  Future<List<PaymentRequest>> getAllPaymentRequests({int? limit, DocumentSnapshot? startAfter}) async {
    var query = FirebaseService.firestore
        .collection('payment_requests')
        .orderBy('requestDate', descending: true);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    query = query.limit(limit ?? _defaultPageSize);
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => PaymentRequest.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<PaymentRequest>> getPendingPaymentRequests() async {
    final snapshot = await FirebaseService.firestore
        .collection('payment_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestDate', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => PaymentRequest.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<PaymentRequest>> getPaymentRequestsByMember(String memberId) async {
    final snapshot = await FirebaseService.firestore
        .collection('payment_requests')
        .where('memberId', isEqualTo: memberId)
        .orderBy('requestDate', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => PaymentRequest.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<PaymentRequest>> getMemberPaymentRequests(String memberId) async {
    return await getPaymentRequestsByMember(memberId);
  }

  Stream<List<PaymentRequest>> watchAllPaymentRequests() {
    return FirebaseService.firestore
        .collection('payment_requests')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentRequest.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<PaymentRequest>> watchPendingPaymentRequests() {
    return FirebaseService.firestore
        .collection('payment_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentRequest.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<PaymentRequest>> watchMemberPaymentRequests(String memberId) {
    return FirebaseService.firestore
        .collection('payment_requests')
        .where('memberId', isEqualTo: memberId)
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentRequest.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<bool> approvePaymentRequest(String requestId, {String? notes, String? approvedBy}) async {
    final firestore = FirebaseService.firestore;
    final requestRef = firestore.collection('payment_requests').doc(requestId);

    // Idempotent claim: only proceed if the request is still pending.
    final existingData = await firestore.runTransaction((tx) async {
      final snap = await tx.get(requestRef);
      if (!snap.exists) return null;
      final data = snap.data()!;
      if (data['status'] != 'pending') return null;
      tx.update(requestRef, {
        'status': 'approved',
        'approvedDate': DateTime.now().toIso8601String(),
        'approvedBy': approvedBy,
        if (notes != null) 'notes': notes,
      });
      return {...data, 'id': requestId};
    });

    if (existingData == null) return false;

    final request = PaymentRequest.fromMap(existingData);

    try {
      if (request.type == PaymentType.contribution) {
        final contribution = Contribution(
          memberId: request.memberId,
          amount: request.amount,
          date: request.requestDate,
          month: request.requestDate.month,
          year: request.requestDate.year,
          createdBy: 'member',
          receiptUrl: request.receiptUrl,
        );

        await FirebaseService.firestore
            .collection('contributions')
            .add(contribution.toMap());

        // Track overpayment as balance
        final contribsSnap = await FirebaseService.firestore
            .collection('contributions')
            .where('memberId', isEqualTo: request.memberId)
            .where('month', isEqualTo: request.requestDate.month)
            .where('year', isEqualTo: request.requestDate.year)
            .get();
        double monthTotal = contribsSnap.docs.fold<double>(
          0.0, (s, d) => s + (d.data()['amount'] as num).toDouble(),
        );

        final memberDoc = await FirebaseService.firestore
            .collection('members')
            .doc(request.memberId)
            .get();

        if (memberDoc.exists) {
          final memberData = memberDoc.data()!;
          final required = (memberData['totalRequired'] as num?)?.toDouble() ?? 0.0;
          double currentBalance = (memberData['balance'] as num?)?.toDouble() ?? 0.0;

          if (monthTotal > required) {
            final excess = monthTotal - required;
            await FirebaseService.firestore
                .collection('members')
                .doc(request.memberId)
                .update({'balance': currentBalance + excess});
          } else if (monthTotal < required && currentBalance > 0) {
            // Apply balance if current month total is below required
            final needed = required - monthTotal;
            final toApply = currentBalance >= needed ? needed : currentBalance;

            if (toApply > 0) {
              // Record the balance application as a contribution
              final balanceContribution = Contribution(
                memberId: request.memberId,
                amount: toApply,
                date: request.requestDate,
                month: request.requestDate.month,
                year: request.requestDate.year,
                notes: 'Applied from balance',
                createdBy: 'system',
              );

              await FirebaseService.firestore
                  .collection('contributions')
                  .add(balanceContribution.toMap());

              await FirebaseService.firestore
                  .collection('members')
                  .doc(request.memberId)
                  .update({'balance': currentBalance - toApply});
            }
          }
        }
      } else if (request.type == PaymentType.loan && request.loanId != null) {
        final repayment = Repayment(
          loanId: request.loanId!,
          amountPaid: request.amount,
          date: DateTime.now(),
        );

        final loanRepo = LoanRepository();
        await loanRepo.addRepayment(repayment);
      }

      final user = FirebaseService.auth.currentUser;
      _activityLog.logActivity(
        action: 'payment_approved',
        entityType: 'payment',
        entityId: requestId,
        performedBy: user?.uid,
        performedByName: user?.displayName,
        details: {
          'memberId': request.memberId,
          'amount': request.amount,
          'type': request.type.name,
        },
      );

      final typeLabel = request.type == PaymentType.contribution ? 'Payment' : 'Repayment';
      final amountLabel = CurrencyFormatter.format(request.amount);
      NotificationRepository.notifyMember(
        request.memberId,
        '$typeLabel Approved',
        'Your $typeLabel of $amountLabel has been approved',
        type: 'payment_request_approved',
      );
    } catch (e) {
      // Post-transaction work failed; revert the approval
      await requestRef.update({
        'status': 'pending',
        'approvedDate': null,
        'approvedBy': null,
        'notes': notes ?? existingData['notes'],
      });
      rethrow;
    }
    return true;
  }

  Future<bool> rejectPaymentRequest(String requestId, {String? notes}) async {
    final firestore = FirebaseService.firestore;
    final requestRef = firestore.collection('payment_requests').doc(requestId);

    final request = await firestore.runTransaction((tx) async {
      final snap = await tx.get(requestRef);
      if (!snap.exists) return null;
      final data = snap.data()!;
      if (data['status'] != 'pending') return null;
      tx.update(requestRef, {
        'status': 'rejected',
        'approvedDate': DateTime.now().toIso8601String(),
        'notes': notes,
      });
      return PaymentRequest.fromMap({...data, 'id': requestId});
    });

    if (request == null) return false;

    final user = FirebaseService.auth.currentUser;
    _activityLog.logActivity(
      action: 'payment_rejected',
      entityType: 'payment',
      entityId: requestId,
      performedBy: user?.uid,
      performedByName: user?.displayName,
      details: {
        'memberId': request.memberId,
        'amount': request.amount,
        'type': request.type.name,
        'reason': notes,
      },
    );

    final typeLabel = request.type == PaymentType.contribution ? 'Payment' : 'Repayment';
    final amountLabel = CurrencyFormatter.format(request.amount);
    final reason = notes != null && notes.isNotEmpty ? ': $notes' : '';
    NotificationRepository.notifyMember(
      request.memberId,
      '$typeLabel Rejected',
      'Your $typeLabel of $amountLabel has been rejected$reason',
      type: 'payment_request_rejected',
    );
    return true;
  }

  Future<void> deletePaymentRequest(String id) async {
    await FirebaseService.firestore
        .collection('payment_requests')
        .doc(id)
        .delete();
  }

  Future<PaymentRequest?> getRequestById(String id) async {
    final doc = await FirebaseService.firestore
        .collection('payment_requests')
        .doc(id)
        .get();
    if (!doc.exists) return null;
    return PaymentRequest.fromMap({...doc.data()!, 'id': doc.id});
  }

  Future<bool> confirmBankReceived(String requestId, {String? confirmedBy}) async {
    final firestore = FirebaseService.firestore;
    final requestRef = firestore.collection('payment_requests').doc(requestId);

    final existingData = await firestore.runTransaction((tx) async {
      final snap = await tx.get(requestRef);
      if (!snap.exists) return null;
      final data = snap.data()!;
      if (data['bankConfirmed'] == true) return null;
      tx.update(requestRef, {
        'bankConfirmed': true,
        'bankConfirmedAt': DateTime.now().toIso8601String(),
        'bankConfirmedBy': confirmedBy,
      });
      return {...data, 'id': requestId};
    });

    if (existingData == null) return false;

    final request = PaymentRequest.fromMap(existingData);
    final memberName = await _getMemberName(request.memberId);
    final typeLabel = request.type == PaymentType.contribution ? 'Contribution' : 'Loan Repayment';
    final amountLabel = CurrencyFormatter.format(request.amount);

    NotificationRepository.notifyAdmins(
      'Bank Confirmed: $typeLabel',
      '$memberName\'s $typeLabel of $amountLabel has been received in the bank account',
      type: 'bank_received',
      data: {'paymentRequestId': requestId, 'memberId': request.memberId},
    );

    _activityLog.logActivity(
      action: 'bank_received',
      entityType: 'payment',
      entityId: requestId,
      performedBy: confirmedBy,
      details: {
        'memberId': request.memberId,
        'amount': request.amount,
        'type': request.type.name,
      },
    );

    return true;
  }

  Future<String> _getMemberName(String memberId) async {
    try {
      final doc = await FirebaseService.firestore.collection('members').doc(memberId).get();
      if (doc.exists) {
        return doc.data()?['name'] ?? 'A member';
      }
    } catch (_) {}
    return 'A member';
  }
}
