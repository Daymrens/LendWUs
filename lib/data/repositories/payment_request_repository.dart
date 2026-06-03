import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_request.dart';
import '../models/contribution.dart';
import '../../core/firebase/firebase_service.dart';

class PaymentRequestRepository {
  Future<String> createPaymentRequest(PaymentRequest request) async {
    final docRef = await FirebaseService.firestore
        .collection('payment_requests')
        .add(request.toMap());
    return docRef.id;
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

    final contribution = Contribution(
      memberId: request.memberId,
      amount: request.amount,
      date: DateTime.now(),
      month: DateTime.now().month,
      year: DateTime.now().year,
    );

    await FirebaseService.firestore
        .collection('contributions')
        .add(contribution.toMap());
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

  Future<PaymentRequest?> getRequestById(String id) async {
    final doc = await FirebaseService.firestore
        .collection('payment_requests')
        .doc(id)
        .get();
    if (!doc.exists) return null;
    return PaymentRequest.fromMap({...doc.data()!, 'id': doc.id});
  }
}
