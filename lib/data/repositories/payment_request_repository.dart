import '../models/payment_request.dart';
import '../models/contribution.dart';
import '../models/repayment.dart';
import 'loan_repository.dart';
import '../../core/firebase/firebase_service.dart';

class PaymentRequestRepository {
  Future<String> createPaymentRequest(PaymentRequest request) async {
    final docRef = await FirebaseService.firestore
        .collection('payment_requests')
        .add(request.toMap());
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

  Future<void> approvePaymentRequest(String requestId, {String? notes}) async {
    final request = await getRequestById(requestId);
    if (request == null) return;

    await FirebaseService.firestore
        .collection('payment_requests')
        .doc(requestId)
        .update({
      'status': 'approved',
      'approvedDate': DateTime.now().toIso8601String(),
      'notes': notes,
    });

    if (request.type == PaymentType.contribution) {
      final contribution = Contribution(
        memberId: request.memberId,
        amount: request.amount,
        date: request.requestDate,
        month: request.requestDate.month,
        year: request.requestDate.year,
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
              date: DateTime.now(),
              month: request.requestDate.month,
              year: request.requestDate.year,
              notes: 'Applied from balance',
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
  }

  Future<void> rejectPaymentRequest(String requestId, {String? notes}) async {
    await FirebaseService.firestore
        .collection('payment_requests')
        .doc(requestId)
        .update({
      'status': 'rejected',
      'approvedDate': DateTime.now().toIso8601String(),
      'notes': notes,
    });
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
}
