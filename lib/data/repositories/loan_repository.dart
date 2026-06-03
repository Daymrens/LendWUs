import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan.dart';
import '../models/repayment.dart';
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

  Future<void> _updateLoanStatus(String loanId) async {
    final loanDoc = await FirebaseService.firestore.collection('loans').doc(loanId).get();
    if (!loanDoc.exists) return;

    final loan = Loan.fromMap({...loanDoc.data()!, 'id': loanDoc.id});
    final repayments = await getRepaymentsByLoan(loanId);

    final totalRepaid = repayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
    final totalDue = loan.principal + (loan.principal * loan.interestRate);

    if (totalRepaid >= totalDue) {
      await FirebaseService.firestore
          .collection('loans')
          .doc(loanId)
          .update({'isFullyRepaid': true});
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
    final activeLoans = loans.where((l) => !l.isFullyRepaid).toList();

    List<Map<String, dynamic>> result = [];
    for (var loan in activeLoans) {
      final remainingBalance = await getRemainingBalance(loan.id!);
      result.add({
        'loan': loan,
        'remainingBalance': remainingBalance,
      });
    }

    return result;
  }
}
