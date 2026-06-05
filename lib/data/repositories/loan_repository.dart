import '../models/loan.dart';
import '../models/repayment.dart';
import 'fund_repository.dart';
import '../../core/firebase/firebase_service.dart';

class LoanRepository {
  Future<List<Loan>> getAllLoans() async {
    final snapshot = await FirebaseService.firestore.collection('loans').get();
    return snapshot.docs
        .map((doc) => Loan.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<Loan>> getActiveLoans() async {
    final snapshot = await FirebaseService.firestore
        .collection('loans')
        .where('isFullyRepaid', isEqualTo: false)
        .get();
    return snapshot.docs
        .map((doc) => Loan.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<Loan>> getLoansByMember(String memberId) async {
    final snapshot = await FirebaseService.firestore
        .collection('loans')
        .where('memberId', isEqualTo: memberId)
        .get();
    return snapshot.docs
        .map((doc) => Loan.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<bool> hasActiveLoan(String memberId) async {
    final snapshot = await FirebaseService.firestore
        .collection('loans')
        .where('memberId', isEqualTo: memberId)
        .where('isFullyRepaid', isEqualTo: false)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<String> addLoan(Loan loan) async {
    if (await hasActiveLoan(loan.memberId)) {
      throw Exception('Member already has an unpaid loan');
    }
    
    final fundRepo = FundRepository();
    final available = await fundRepo.getAvailableToLoan();
    if (loan.principal > available) {
      throw Exception('Insufficient fund balance');
    }

    final docRef = await FirebaseService.firestore.collection('loans').add(loan.toMap());
    return docRef.id;
  }

  Future<void> updateLoan(Loan loan) async {
    await FirebaseService.firestore
        .collection('loans')
        .doc(loan.id!)
        .update(loan.toMap());
  }

  Future<String> addRepayment(Repayment repayment) async {
    final docRef = await FirebaseService.firestore
        .collection('repayments')
        .add(repayment.toMap());

    await _updateLoanStatus(repayment.loanId);

    return docRef.id;
  }

  Future<List<Repayment>> getAllRepayments() async {
    final snapshot = await FirebaseService.firestore.collection('repayments').get();
    return snapshot.docs
        .map((doc) => Repayment.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<Repayment>> getRepaymentsByLoan(String loanId) async {
    final snapshot = await FirebaseService.firestore
        .collection('repayments')
        .where('loanId', isEqualTo: loanId)
        .get();
    return snapshot.docs
        .map((doc) => Repayment.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<void> deleteLoan(String id) async {
    await FirebaseService.firestore.collection('loans').doc(id).delete();
  }

  Future<void> updateRepayment(Repayment repayment) async {
    await FirebaseService.firestore
        .collection('repayments')
        .doc(repayment.id!)
        .update(repayment.toMap());
  }

  Future<void> deleteRepayment(String id) async {
    await FirebaseService.firestore.collection('repayments').doc(id).delete();
  }

  Future<void> _updateLoanStatus(String loanId) async {
    final firestore = FirebaseService.firestore;
    final loanRef = firestore.collection('loans').doc(loanId);

    final loanDoc = await loanRef.get();
    if (!loanDoc.exists) return;

    final loan = Loan.fromMap({...loanDoc.data()!, 'id': loanDoc.id});
    if (loan.isFullyRepaid) return;

    final repaymentsSnap = await firestore
        .collection('repayments')
        .where('loanId', isEqualTo: loanId)
        .get();

    final totalRepaid = repaymentsSnap.docs
        .fold<double>(0.0, (sum, d) => sum + (d.data()['amountPaid'] as num).toDouble());
    final totalDue = loan.principal + (loan.principal * loan.interestRate);

    if (totalRepaid >= totalDue) {
      await firestore.runTransaction((txn) async {
        final fresh = await txn.get(loanRef);
        if (!fresh.exists) return;
        final data = fresh.data()!;
        if (data['isFullyRepaid'] == true) return;
        txn.update(loanRef, {'isFullyRepaid': true});
      });
    }
  }

  Future<double> getTotalLoansIssued() async {
    final loans = await getAllLoans();
    return loans.fold<double>(0.0, (sum, loan) => sum + loan.principal);
  }

  Future<double> getTotalInterestEarned() async {
    final loans = await getAllLoans();
    final repayments = await getAllRepayments();

    double totalInterest = 0.0;
    for (var loan in loans) {
      final loanRepayments = repayments.where((r) => r.loanId == loan.id);
      final totalRepaid = loanRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
      final excess = totalRepaid - loan.principal;
      if (excess > 0) totalInterest += excess;
    }

    return totalInterest;
  }

  Stream<List<Loan>> watchAllLoans() {
    return FirebaseService.firestore.collection('loans').snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => Loan.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<Loan>> watchActiveLoans() {
    return FirebaseService.firestore
        .collection('loans')
        .where('isFullyRepaid', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Loan.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<Repayment>> watchAllRepayments() {
    return FirebaseService.firestore.collection('repayments').snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => Repayment.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<double> getRemainingBalance(String loanId) async {
    final loanDoc = await FirebaseService.firestore.collection('loans').doc(loanId).get();
    if (!loanDoc.exists) return 0.0;

    final loan = Loan.fromMap({...loanDoc.data()!, 'id': loanDoc.id});
    final repayments = await getRepaymentsByLoan(loanId);

    final totalRepaid = repayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
    final totalDue = loan.principal + (loan.principal * loan.interestRate);

    return (totalDue - totalRepaid).clamp(0.0, double.infinity);
  }

  Future<List<Map<String, dynamic>>> getMemberActiveLoans(String memberId) async {
    final loans = await getLoansByMember(memberId);
    final activeLoans = loans.where((l) => !l.isFullyRepaid && l.id != null).toList();

    final balances = await Future.wait(
      activeLoans.map((loan) => getRemainingBalance(loan.id!)),
    );

    return List.generate(activeLoans.length, (i) => {
          'loan': activeLoans[i],
          'remainingBalance': balances[i],
        });
  }
}
