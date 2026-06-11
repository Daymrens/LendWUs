import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan.dart';
import '../models/repayment.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/utils/interest_calculator.dart';

class LoanRepository {
  static const int _defaultPageSize = 100;

  Future<List<Loan>> getAllLoans({int? limit, DocumentSnapshot? startAfter}) async {
    Query<Map<String, dynamic>> query = FirebaseService.firestore.collection('loans');
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    query = query.limit(limit ?? _defaultPageSize);
    final snapshot = await query.get();
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

    return await firestore.runTransaction((txn) async {
      final existingSnap = await firestore
          .collection('loans')
          .where('memberId', isEqualTo: loan.memberId)
          .where('isFullyRepaid', isEqualTo: false)
          .get();

      for (final doc in existingSnap.docs) {
        final loanRef = firestore.collection('loans').doc(doc.id);
        final refreshed = await txn.get(loanRef);
        if (refreshed.exists && refreshed.data()?['isFullyRepaid'] == false) {
          throw Exception('Member already has an unpaid loan');
        }
      }

      final docRef = firestore.collection('loans').doc();
      txn.set(docRef, loan.toMap());
      return docRef.id;
    });
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

    final repaymentIds = await firestore
        .collection('repayments')
        .where('loanId', isEqualTo: loanId)
        .get()
        .then((snap) => snap.docs.map((d) => d.id).toList());

    await firestore.runTransaction((txn) async {
      final loanDoc = await txn.get(loanRef);
      if (!loanDoc.exists) return;

      final loan = Loan.fromMap({...loanDoc.data()!, 'id': loanDoc.id});
      if (loan.isFullyRepaid) return;

      final repayments = <Repayment>[];
      for (final id in repaymentIds) {
        final repaymentDoc = await txn.get(firestore.collection('repayments').doc(id));
        if (repaymentDoc.exists) {
          repayments.add(Repayment.fromMap({...repaymentDoc.data()!, 'id': repaymentDoc.id}));
        }
      }

      if (InterestCalculator.isLoanFullyRepaid(loan, repayments)) {
        txn.update(loanRef, {'isFullyRepaid': true});
      }
    });
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

  Stream<List<Loan>> watchLoansByMember(String memberId) {
    return FirebaseService.firestore
        .collection('loans')
        .where('memberId', isEqualTo: memberId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Loan.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<Map<String, dynamic>>> watchMemberActiveLoans(String memberId) {
    return watchLoansByMember(memberId).asyncMap((loans) async {
      final activeLoans = loans.where((l) => !l.isFullyRepaid && l.id != null).toList();
      final balances = await Future.wait(
        activeLoans.map((loan) => getRemainingBalance(loan.id!)),
      );
      return List.generate(activeLoans.length, (i) => {
            'loan': activeLoans[i],
            'remainingBalance': balances[i],
          });
    });
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
