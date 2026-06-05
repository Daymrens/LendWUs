import '../../core/utils/firestore_helpers.dart';

class Loan {
  String? id;
  String memberId;
  double principal;
  double interestRate;
  DateTime issuedDate;
  DateTime dueDate;
  bool isFullyRepaid;

  Loan({
    this.id,
    required this.memberId,
    required this.principal,
    required this.interestRate,
    required this.issuedDate,
    required this.dueDate,
    this.isFullyRepaid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'memberId': memberId,
      'principal': principal,
      'interestRate': interestRate,
      'issuedDate': issuedDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'isFullyRepaid': isFullyRepaid,
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'],
      memberId: map['memberId'] ?? '',
      principal: (map['principal'] as num?)?.toDouble() ?? 0.0,
      interestRate: (map['interestRate'] as num?)?.toDouble() ?? 0.0,
      issuedDate: parseFirestoreDate(map['issuedDate']),
      dueDate: parseFirestoreDate(map['dueDate']),
      isFullyRepaid: map['isFullyRepaid'] == true || map['isFullyRepaid'] == 1,
    );
  }
}
