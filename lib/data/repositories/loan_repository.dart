import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan.dart';
import '../models/repayment.dart';
import 'fund_repository.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/utils/interest_calculator.dart';

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
    final firestore = FirebaseService.firestore;
    String? loanId;

    await firestore.runTransaction((tx) async {
      final activeLoansSnap = await firestore
          .collection('loans')
          .where('memberId', isEqualTo: loan.memberId)
          .where('isFullyRepaid', isEqualTo: false)
          .limit(1)
          .get();
      
      if (activeLoansSnap.docs.isNotEmpty) {
        throw Exception('Member already has an unpaid loan');
      }

      final fundRepo = FundRepository();
      final available = await fundRepo.getAvailableToLoan();
      if (loan.principal > available) {
        throw Exception('Insufficient fund balance');
      }

      final docRef = firestore.collection('loans').doc();
      loanId = docRef.id;
      tx.set(docRef, loan.toMap());
    });

    return loanId!;
  }

  Future<void> updateLoan(Loan loan) async {
    await FirebaseService.firestore
        .collection('loans')
        .doc(loan.id!)
        .update(loan.toMap());
    
    await _updateLoanStatus(loan.id!);
  }

  Future<String> addRepayment(Repayment repayment, {Transaction? transaction}) async {
    final firestore = FirebaseService.firestore;
    final ref = firestore.collection('repayments').doc();
    final String repaymentId = ref.id;

    if (transaction != null) {
      transaction.set(ref, repayment.toMap());
      await _updateLoanStatus(repayment.loanId, transaction: transaction);
      return repaymentId;
    } else {
      await ref.set(repayment.toMap());
      await _updateLoanStatus(repayment.loanId);
      return repaymentId;
    }
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
    
    await _updateLoanStatus(repayment.loanId);
  }

  Future<void> deleteRepayment(String id) async {
    final firestore = FirebaseService.firestore;
    final doc = await firestore.collection('repayments').doc(id).get();
    if (!doc.exists) return;
    
    final repayment = Repayment.fromMap({...doc.data()!, 'id': doc.id});
    await firestore.collection('repayments').doc(id).delete();
    
    await _updateLoanStatus(repayment.loanId);
  }

  Future<void> _updateLoanStatus(String loanId, {Transaction? transaction}) async {
    final firestore = FirebaseService.firestore;
    final loanRef = firestore.collection('loans').doc(loanId);

    // Fetch repayments outside transaction because Transaction.get(Query) is not supported
    final repaymentsSnap = await firestore
        .collection('repayments')
        .where('loanId', isEqualTo: loanId)
        .get();

    final repayments = repaymentsSnap.docs
        .map((d) => Repayment.fromMap({...d.data(), 'id': d.id}))
        .toList();

    Future<void> action(Transaction txn) async {
      final loanDoc = await txn.get(loanRef);
      if (!loanDoc.exists) return;

      final loan = Loan.fromMap({...loanDoc.data()!, 'id': loanDoc.id});
      if (loan.isFullyRepaid) {
        // If it was fully repaid, check if it still is
        if (!InterestCalculator.isLoanFullyRepaid(loan, repayments)) {
          txn.update(loanRef, {'isFullyRepaid': false});
        }
        return;
      }

      if (InterestCalculator.isLoanFullyRepaid(loan, repayments)) {
        txn.update(loanRef, {'isFullyRepaid': true});
      }
    }

    if (transaction != null) {
      await action(transaction);
    } else {
      await firestore.runTransaction(action);
    }
  }

  Future<double> getTotalLoansIssued() async {
    final loans = await getAllLoans();
    return loans.fold<double>(0.0, (sum, loan) => sum + loan.principal);
  }

  Future<double> getTotalInterestEarned() async {
    final loans = await getAllLoans();
    final repayments = await getAllRepayments();
    return InterestCalculator.calculateTotalInterestEarned(loans, repayments);
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

    return InterestCalculator.calculateRemainingBalance(loan, repayments);
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
