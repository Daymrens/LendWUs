import '../../core/utils/firestore_helpers.dart';

class Repayment {
  String? id;
  String loanId;
  int amountPaid;
  DateTime date;

  Repayment({
    this.id,
    required this.loanId,
    required this.amountPaid,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'loanId': loanId,
      'amountPaid': amountPaid,
      'date': date.toIso8601String(),
    };
  }

  factory Repayment.fromMap(Map<String, dynamic> map) {
    return Repayment(
      id: map['id'],
      loanId: map['loanId'] ?? '',
      amountPaid: (map['amountPaid'] as num?)?.toInt() ?? 0,
      date: parseFirestoreDate(map['date']),
    );
  }
}
