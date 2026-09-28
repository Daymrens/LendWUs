import '../../core/utils/firestore_helpers.dart';

class Contribution {
  String? id;
  String memberId;
  int amount;
  DateTime date;
  int month;
  int year;
  String? notes;
  String? createdBy;
  String? receiptUrl;
  String? receiptHash;
  String? sourceRequestId;

  Contribution({
    this.id,
    required this.memberId,
    required this.amount,
    required this.date,
    required this.month,
    required this.year,
    this.notes,
    this.createdBy,
    this.receiptUrl,
    this.receiptHash,
    this.sourceRequestId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'memberId': memberId,
      'amount': amount,
      'date': date.toIso8601String(),
      'month': month,
      'year': year,
      'notes': notes,
      if (createdBy != null) 'createdBy': createdBy,
      'receiptUrl': receiptUrl,
      'receiptHash': receiptHash,
      if (sourceRequestId != null) 'sourceRequestId': sourceRequestId,
    };
  }

  factory Contribution.fromMap(Map<String, dynamic> map) {
    return Contribution(
      id: map['id'],
      memberId: map['memberId'] ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      date: parseFirestoreDate(map['date']),
      month: map['month'] ?? DateTime.now().month,
      year: map['year'] ?? DateTime.now().year,
      notes: map['notes'],
      createdBy: map['createdBy'],
      receiptUrl: map['receiptUrl'],
      receiptHash: map['receiptHash'],
    );
  }
}
