import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firebase_service.dart';
import '../models/loan_receipt.dart';

class LoanReceiptRepository {
  static Future<void> generateReceipts({
    required String loanId,
    required String memberId,
    required String memberName,
    required double principal,
    required double interestRate,
    required DateTime issuedDate,
    required DateTime dueDate,
  }) async {
    final interestAmount = principal * interestRate;
    final totalAmountDue = principal + interestAmount;
    final now = DateTime.now();
    final receiptNumber = _buildReceiptNumber(issuedDate);

    final batch = FirebaseService.firestore.batch();

    // Admin copy
    final adminRef = FirebaseService.firestore.collection('loan_receipts').doc();
    batch.set(adminRef, {
      'loanId': loanId,
      'receiptNumber': receiptNumber,
      'memberId': memberId,
      'memberName': memberName,
      'principal': principal,
      'interestRate': interestRate,
      'interestAmount': interestAmount,
      'totalAmountDue': totalAmountDue,
      'issuedDate': issuedDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': 'active',
      'copyFor': 'admin',
      'generatedAt': now.toIso8601String(),
    });

    // Borrower copy
    final borrowerRef = FirebaseService.firestore.collection('loan_receipts').doc();
    batch.set(borrowerRef, {
      'loanId': loanId,
      'receiptNumber': receiptNumber,
      'memberId': memberId,
      'memberName': memberName,
      'principal': principal,
      'interestRate': interestRate,
      'interestAmount': interestAmount,
      'totalAmountDue': totalAmountDue,
      'issuedDate': issuedDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': 'active',
      'copyFor': 'borrower',
      'generatedAt': now.toIso8601String(),
    });

    await batch.commit();
  }

  static String _buildReceiptNumber(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final ts = DateTime.now().millisecondsSinceEpoch % 100000;
    return 'LR-$y$m-${ts.toString().padLeft(5, '0')}';
  }

  static Future<List<LoanReceipt>> getReceiptsByLoanId(String loanId) async {
    final snap = await FirebaseService.firestore
        .collection('loan_receipts')
        .where('loanId', isEqualTo: loanId)
        .get();
    return snap.docs.map((d) => LoanReceipt.fromMap({'id': d.id, ...d.data()})).toList();
  }

  static Future<List<LoanReceipt>> getReceiptsByMemberId(String memberId) async {
    final snap = await FirebaseService.firestore
        .collection('loan_receipts')
        .where('memberId', isEqualTo: memberId)
        .orderBy('generatedAt', descending: true)
        .get();
    return snap.docs.map((d) => LoanReceipt.fromMap({'id': d.id, ...d.data()})).toList();
  }

  static Stream<QuerySnapshot> streamReceiptsForLoan(String loanId) {
    return FirebaseService.firestore
        .collection('loan_receipts')
        .where('loanId', isEqualTo: loanId)
        .snapshots();
  }

  static Future<bool> hasReceipts(String loanId) async {
    final snap = await FirebaseService.firestore
        .collection('loan_receipts')
        .where('loanId', isEqualTo: loanId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
