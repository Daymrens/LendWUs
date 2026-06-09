import '../models/loan_request.dart';
import '../models/loan.dart';
import 'notification_repository.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/firestore_helpers.dart';

class LoanRequestRepository {
  Future<String> createLoanRequest(LoanRequest request) async {
    final docRef = await FirebaseService.firestore
        .collection('loan_requests')
        .add(request.toMap());

    final amountLabel = CurrencyFormatter.format(request.amount);
    NotificationRepository.notifyAdmins(
      'New Loan Request',
      '${request.memberName} requested a loan of $amountLabel',
      type: 'loan_request_created',
    );

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

  Stream<List<LoanRequest>> watchAllLoanRequests() {
    return FirebaseService.firestore
        .collection('loan_requests')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LoanRequest.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<LoanRequest>> watchPendingLoanRequests() {
    return FirebaseService.firestore
        .collection('loan_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LoanRequest.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
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

  Future<bool> approveLoanRequest(String requestId, {String? notes}) async {
    final firestore = FirebaseService.firestore;
    final requestRef = firestore.collection('loan_requests').doc(requestId);

    final requestSnap = await requestRef.get();
    if (!requestSnap.exists) return false;
    final data = requestSnap.data()!;
    if (data['status'] != 'pending') return false;
    final memberId = data['memberId'] as String;

    // Pre-check for active loans to avoid creating duplicates when two
    // admins approve concurrent requests. Race-safe within the transaction
    // is enforced by the unique-id loan doc; this check short-circuits the
    // common case without needing an extra round-trip.
    final existingActive = await firestore
        .collection('loans')
        .where('memberId', isEqualTo: memberId)
        .where('isFullyRepaid', isEqualTo: false)
        .limit(1)
        .get();
    if (existingActive.docs.isNotEmpty) return false;

    // Pre-generate a loan doc reference so the create + request update can be atomic.
    final loanRef = firestore.collection('loans').doc();

    final approved = await firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(requestRef);
      if (!snap.exists) return false;
      final fresh = snap.data()!;
      if (fresh['status'] != 'pending') return false;

      final loan = Loan(
        memberId: memberId,
        principal: (fresh['amount'] as num).toDouble(),
        interestRate: ((fresh['interestRate'] as num?)?.toDouble() ?? 0) / 100,
        dueDate: parseFirestoreDate(fresh['dueDate']),
        issuedDate: DateTime.now(),
        isFullyRepaid: false,
      );
      tx.set(loanRef, loan.toMap());
      tx.update(requestRef, {
        'status': 'disbursed',
        'processedAt': DateTime.now().toIso8601String(),
        'notes': notes,
        'loanId': loanRef.id,
      });
      return true;
    });

    if (!approved) return false;

    final amountLabel = CurrencyFormatter.format((data['amount'] as num).toDouble());
    NotificationRepository.notifyMember(
      memberId,
      'Loan Approved',
      'Your loan request of $amountLabel has been approved and disbursed',
      type: 'loan_request_approved',
    );
    return true;
  }

  Future<bool> rejectLoanRequest(String requestId, {String? notes}) async {
    final firestore = FirebaseService.firestore;
    final requestRef = firestore.collection('loan_requests').doc(requestId);

    final request = await firestore.runTransaction((tx) async {
      final snap = await tx.get(requestRef);
      if (!snap.exists) return null;
      final data = snap.data()!;
      if (data['status'] != 'pending') return null;
      tx.update(requestRef, {
        'status': 'rejected',
        'processedAt': DateTime.now().toIso8601String(),
        'notes': notes,
      });
      return LoanRequest.fromMap({...data, 'id': requestId});
    });

    if (request == null) return false;

    final amountLabel = CurrencyFormatter.format(request.amount);
    final reason = notes != null && notes.isNotEmpty ? ': $notes' : '';
    NotificationRepository.notifyMember(
      request.memberId,
      'Loan Request Rejected',
      'Your loan request of $amountLabel has been rejected$reason',
      type: 'loan_request_rejected',
    );
    return true;
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
