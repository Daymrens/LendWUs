import '../models/loan_request.dart';
import '../models/loan.dart';
import '../../core/firebase/firebase_service.dart';

class LoanRequestRepository {
  Future<String> createLoanRequest(LoanRequest request) async {
    final docRef = await FirebaseService.firestore
        .collection('loan_requests')
        .add(request.toMap());
    return docRef.id;
  }

  Future<List<LoanRequest>> getAllLoanRequests() async {
    final snapshot = await FirebaseService.firestore
        .collection('loan_requests')
        .orderBy('requestedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => LoanRequest.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<LoanRequest>> getPendingLoanRequests() async {
    final snapshot = await FirebaseService.firestore
        .collection('loan_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => LoanRequest.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<LoanRequest>> getLoanRequestsByMember(String memberId) async {
    final snapshot = await FirebaseService.firestore
        .collection('loan_requests')
        .where('memberId', isEqualTo: memberId)
        .orderBy('requestedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => LoanRequest.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<LoanRequest>> getMemberLoanRequests(String memberId) async {
    return await getLoanRequestsByMember(memberId);
  }

  Stream<List<LoanRequest>> watchMemberLoanRequests(String memberId) {
    return FirebaseService.firestore
        .collection('loan_requests')
        .where('memberId', isEqualTo: memberId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LoanRequest.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> approveLoanRequest(String requestId, {String? notes}) async {
    final request = await getRequestById(requestId);
    if (request == null) return;

    await FirebaseService.firestore
        .collection('loan_requests')
        .doc(requestId)
        .update({
      'status': 'approved',
      'processedAt': DateTime.now().toIso8601String(),
      'notes': notes,
    });

    final loan = Loan(
      memberId: request.memberId,
      principal: request.amount,
      interestRate: request.interestRate / 100,
      dueDate: request.dueDate,
      issuedDate: DateTime.now(),
      isFullyRepaid: false,
    );

    final loanRef = await FirebaseService.firestore
        .collection('loans')
        .add(loan.toMap());

    await FirebaseService.firestore
        .collection('loan_requests')
        .doc(requestId)
        .update({
      'status': 'disbursed',
      'loanId': loanRef.id,
    });
  }

  Future<void> rejectLoanRequest(String requestId, {String? notes}) async {
    await FirebaseService.firestore
        .collection('loan_requests')
        .doc(requestId)
        .update({
      'status': 'rejected',
      'processedAt': DateTime.now().toIso8601String(),
      'notes': notes,
    });
  }

  Future<void> deleteLoanRequest(String id) async {
    await FirebaseService.firestore
        .collection('loan_requests')
        .doc(id)
        .delete();
  }

  Future<LoanRequest?> getRequestById(String id) async {
    final doc = await FirebaseService.firestore
        .collection('loan_requests')
        .doc(id)
        .get();
    if (!doc.exists) return null;
    return LoanRequest.fromMap({...doc.data()!, 'id': doc.id});
  }
}
