import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan_request.dart';
import '../models/loan.dart';
import 'activity_log_repository.dart';
import 'notification_repository.dart';
import 'loan_receipt_repository.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/firestore_helpers.dart';

class LoanRequestRepository {
  final ActivityLogRepository _activityLog;

  LoanRequestRepository({ActivityLogRepository? activityLog})
      : _activityLog = activityLog ?? ActivityLogRepository();
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
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LoanRequest.fromMap({...doc.data(), 'id': doc.id}))
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt)));
  }

  Future<bool> approveLoanRequest(String requestId, {String? notes}) async {
    final firestore = FirebaseService.firestore;
    final requestRef = firestore.collection('loan_requests').doc(requestId);

    final requestSnap = await requestRef.get();
    if (!requestSnap.exists) return false;
    final data = requestSnap.data()!;
    if (data['status'] != 'pending') return false;
    final memberId = data['memberId'] as String;
    final principal = (data['amount'] as num).toDouble();
    final interestRate = (data['interestRate'] as num?)?.toDouble() ?? 0;
    final dueDate = parseFirestoreDate(data['dueDate']);

    // --- Eligibility checks (§3, §5.2) ---
    if (principal <= 0) {
      await _rejectRequest(requestRef, notes,
          reason: 'Loan amount must be greater than zero');
      return false;
    }

    if (!dueDate.isAfter(DateTime.now())) {
      await _rejectRequest(requestRef, notes,
          reason: 'Due date must be in the future');
      return false;
    }

    final memberSnap = await firestore.collection('members').doc(memberId).get();
    final memberData = memberSnap.data();
    if (memberData == null || memberData['isActive'] != true) {
      await _rejectRequest(requestRef, notes,
          reason: 'Member is not active');
      return false;
    }

    // Pre-check for active loans to avoid creating duplicates when two
    // admins approve concurrent requests. The transaction below re-checks
    // the request status to prevent double-approval of the same request.
    final existingActive = await firestore
        .collection('loans')
        .where('memberId', isEqualTo: memberId)
        .where('isFullyRepaid', isEqualTo: false)
        .limit(1)
        .get();
    if (existingActive.docs.isNotEmpty) {
      await _rejectRequest(requestRef, notes,
          reason: 'Member already has an unpaid loan');
      return false;
    }

    // Compute availableToLoan: fundBalance - outstanding from non-repaid loans
    // NOTE: This check runs outside the transaction because Firestore
    // transactions cannot read entire collections (only individual docs).
    // A concurrent admin approval could slightly alter the balance between
    // this check and the transaction below — this is a known limitation
    // of the Spark plan (no Cloud Functions for server-side enforcement).
    // The transaction re-verifies the request status to prevent
    // double-approval of the same request.
    final contribSnap = await firestore.collection('contributions').get();
    final loanSnap = await firestore.collection('loans').get();
    final repaySnap = await firestore.collection('repayments').get();

    final totalContributions = contribSnap.docs.fold<double>(
        0.0, (sum, d) => sum + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
    final totalLoansIssued = loanSnap.docs.fold<double>(
        0.0, (sum, d) => sum + ((d.data()['principal'] as num?)?.toDouble() ?? 0));
    final totalRepayments = repaySnap.docs.fold<double>(
        0.0, (sum, d) => sum + ((d.data()['amountPaid'] as num?)?.toDouble() ?? 0));
    final fundBalance = totalContributions - totalLoansIssued + totalRepayments;

    double outstanding = 0.0;
    final repayByLoan = <String, List<double>>{};
    for (final doc in repaySnap.docs) {
      final r = doc.data();
      final loanId = r['loanId'] as String?;
      final amount = (r['amountPaid'] as num?)?.toDouble() ?? 0;
      repayByLoan.putIfAbsent(loanId!, () => []).add(amount);
    }
    for (final doc in loanSnap.docs) {
      final l = doc.data();
      if (l['isFullyRepaid'] == true) continue;
      final loanPrincipal = (l['principal'] as num?)?.toDouble() ?? 0;
      final rate = (l['interestRate'] as num?)?.toDouble() ?? 0;
      final loanId = doc.id;
      final totalRepaid =
          (repayByLoan[loanId] ?? []).fold<double>(0.0, (s, a) => s + a);
      final totalDue = loanPrincipal + (loanPrincipal * rate);
      final remaining = totalDue - totalRepaid;
      if (remaining > 0) outstanding += remaining;
    }

    final availableToLoan = fundBalance - outstanding;
    if (principal > availableToLoan) {
      await _rejectRequest(requestRef, notes,
          reason: 'Insufficient fund balance');
      return false;
    }

    // --- End eligibility checks ---

    // Pre-generate a loan doc reference so the create + request update can be atomic.
    final loanRef = firestore.collection('loans').doc();

    final approved = await firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(requestRef);
      if (!snap.exists) return false;
      final fresh = snap.data()!;
      if (fresh['status'] != 'pending') return false;

      final loan = Loan(
        memberId: memberId,
        principal: principal,
        interestRate: ((fresh['interestRate'] as num?)?.toDouble() ?? 0) / 100,
        dueDate: dueDate,
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

    final memberName = memberData?['name'] as String? ?? 'Unknown';
    final loanInterestRate = ((data['interestRate'] as num?)?.toDouble() ?? 0) / 100;
    await LoanReceiptRepository.generateReceipts(
      loanId: loanRef.id,
      memberId: memberId,
      memberName: memberName,
      principal: principal,
      interestRate: loanInterestRate,
      issuedDate: DateTime.now(),
      dueDate: dueDate,
    );

    final user = FirebaseService.auth.currentUser;
    _activityLog.logActivity(
      action: 'loan_approved',
      entityType: 'loan',
      entityId: loanRef.id,
      performedBy: user?.uid,
      performedByName: user?.displayName,
      details: {
        'principal': principal,
        'dueDate': dueDate.toIso8601String(),
        'interestRate': interestRate,
      },
    );

    final amountLabel = CurrencyFormatter.format(principal);
    NotificationRepository.notifyMember(
      memberId,
      'Loan Approved',
      'Your loan request of $amountLabel has been approved and disbursed',
      type: 'loan_request_approved',
    );
    return true;
  }

  Future<void> _rejectRequest(DocumentReference requestRef, String? notes,
      {required String reason}) async {
    await requestRef.update({
      'status': 'rejected',
      'processedAt': DateTime.now().toIso8601String(),
      'notes': notes ?? reason,
    });
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

    final user = FirebaseService.auth.currentUser;
    _activityLog.logActivity(
      action: 'loan_rejected',
      entityType: 'loan_request',
      entityId: requestId,
      performedBy: user?.uid,
      performedByName: user?.displayName,
      details: {
        'memberId': request.memberId,
        'amount': request.amount,
        'reason': notes,
      },
    );

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
