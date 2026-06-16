import '../../core/utils/firestore_helpers.dart';

class LoanReceipt {
  String? id;
  String loanId;
  String receiptNumber;
  String memberId;
  String memberName;
  double principal;
  double interestRate;
  double interestAmount;
  double totalAmountDue;
  DateTime issuedDate;
  DateTime dueDate;
  String status;
  String copyFor;
  DateTime generatedAt;

  LoanReceipt({
    this.id,
    required this.loanId,
    required this.receiptNumber,
    required this.memberId,
    required this.memberName,
    required this.principal,
    required this.interestRate,
    required this.interestAmount,
    required this.totalAmountDue,
    required this.issuedDate,
    required this.dueDate,
    this.status = 'active',
    required this.copyFor,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
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
      'status': status,
      'copyFor': copyFor,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  factory LoanReceipt.fromMap(Map<String, dynamic> map) {
    return LoanReceipt(
      id: map['id'],
      loanId: map['loanId'] ?? '',
      receiptNumber: map['receiptNumber'] ?? '',
      memberId: map['memberId'] ?? '',
      memberName: map['memberName'] ?? '',
      principal: (map['principal'] as num?)?.toDouble() ?? 0.0,
      interestRate: (map['interestRate'] as num?)?.toDouble() ?? 0.0,
      interestAmount: (map['interestAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmountDue: (map['totalAmountDue'] as num?)?.toDouble() ?? 0.0,
      issuedDate: parseFirestoreDate(map['issuedDate']),
      dueDate: parseFirestoreDate(map['dueDate']),
      status: map['status'] ?? 'active',
      copyFor: map['copyFor'] ?? 'borrower',
      generatedAt: parseFirestoreDate(map['generatedAt']),
    );
  }
}
