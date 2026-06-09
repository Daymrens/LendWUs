import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_request.dart';
import '../models/contribution.dart';
import '../models/repayment.dart';
import '../models/loan.dart';
import 'loan_repository.dart';
import 'notification_repository.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/interest_calculator.dart';
import '../models/member.dart';

class PaymentRequestRepository {
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

    return docRef.id;
  }

  Future<List<PaymentRequest>> getAllPaymentRequests() async {
    final snapshot = await FirebaseService.firestore
        .collection('payment_requests')
        .orderBy('requestDate', descending: true)
        .get();
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

    // Fetch necessary data outside transaction
    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) return false;
    final request = PaymentRequest.fromMap({...requestDoc.data()!, 'id': requestDoc.id});
    if (request.status != 'pending') return false;

    try {
      await firestore.runTransaction((tx) async {
        // 1. Update request status
        tx.update(requestRef, {
          'status': 'approved',
          'approvedDate': DateTime.now().toIso8601String(),
          'approvedBy': approvedBy,
          if (notes != null) 'notes': notes,
        });

        final memberRef = firestore.collection('members').doc(request.memberId);
        final memberSnap = await tx.get(memberRef);
        if (!memberSnap.exists) throw Exception('Member not found');
        final member = Member.fromMap({...memberSnap.data()!, 'id': memberSnap.id});

        // 2. Add contribution or repayment
        if (request.type == PaymentType.contribution) {
          final contribution = Contribution(
            memberId: request.memberId,
            amount: request.amount,
            date: request.requestDate,
            month: request.requestDate.month,
            year: request.requestDate.year,
            createdBy: 'member',
          );
          
          final contribRef = firestore.collection('contributions').doc();
          tx.set(contribRef, contribution.toMap());

          // 3. Update member balance and monthly total atomically
          final requestMonthYear = '${request.requestDate.year}-${request.requestDate.month}';
          double monthTotalBefore = (member.currentMonthYear == requestMonthYear) ? member.currentMonthTotal : 0.0;
          double currentBalance = member.balance;

          double newMonthTotal = monthTotalBefore + request.amount;
          double newBalance = currentBalance;

          if (newMonthTotal > member.totalRequired) {
            final excess = newMonthTotal - member.totalRequired;
            newBalance += excess;
          } else if (newMonthTotal < member.totalRequired && currentBalance > 0) {
            final needed = member.totalRequired - newMonthTotal;
            final toApply = currentBalance >= needed ? needed : currentBalance;

            if (toApply > 0) {
              final balanceContrib = Contribution(
                memberId: request.memberId,
                amount: toApply,
                date: DateTime.now(),
                month: request.requestDate.month,
                year: request.requestDate.year,
                notes: 'Applied from balance',
                createdBy: 'system',
              );
              final balRef = firestore.collection('contributions').doc();
              tx.set(balRef, balanceContrib.toMap());
              
              newBalance -= toApply;
              newMonthTotal += toApply;
            }
          }

          tx.update(memberRef, {
            'balance': newBalance,
            'currentMonthTotal': newMonthTotal,
            'currentMonthYear': requestMonthYear,
          });

        } else if (request.type == PaymentType.loan && request.loanId != null) {
          final repayment = Repayment(
            loanId: request.loanId!,
            amountPaid: request.amount,
            date: DateTime.now(),
          );
          
          final repayRef = firestore.collection('repayments').doc();
          tx.set(repayRef, repayment.toMap());
          
          // Update loan status (atomic within this tx)
          final loanRef = firestore.collection('loans').doc(request.loanId!);
          final loanSnap = await tx.get(loanRef);
          if (loanSnap.exists) {
            final loan = Loan.fromMap({...loanSnap.data()!, 'id': loanSnap.id});
            if (!loan.isFullyRepaid) {
              final repaymentsSnap = await firestore
                  .collection('repayments')
                  .where('loanId', isEqualTo: request.loanId)
                  .get();
              final repayments = repaymentsSnap.docs
                  .map((d) => Repayment.fromMap({...d.data(), 'id': d.id}))
                  .toList();
              
              repayments.add(repayment);

              if (InterestCalculator.isLoanFullyRepaid(loan, repayments)) {
                tx.update(loanRef, {'isFullyRepaid': true});
              }
            }
          }
        }
      });

      // 4. Notify (outside transaction)
      final typeLabel = request.type == PaymentType.contribution ? 'Payment' : 'Repayment';
      final amountLabel = CurrencyFormatter.format(request.amount);
      NotificationRepository.notifyMember(
        request.memberId,
        '$typeLabel Approved',
        'Your $typeLabel of $amountLabel has been approved',
        type: 'payment_request_approved',
      );
      
      return true;
    } catch (e) {
      debugPrint('approvePaymentRequest error: $e');
      return false;
    }
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
