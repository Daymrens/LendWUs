import '../../core/utils/firestore_helpers.dart';

enum PaymentStatus { pending, approved, rejected }
enum PaymentType { contribution, loan }

class PaymentRequest {
  String? id;
  String memberId;
  String? loanId;
  PaymentType type;
  double amount;
  String? receiptPath;
  String? receiptUrl;
  PaymentStatus status;
  DateTime requestDate;
  DateTime? approvedDate;
  String? approvedBy;
  String? notes;
  String? rejectReason;

  PaymentRequest({
    this.id,
    required this.memberId,
    this.loanId,
    required this.type,
    required this.amount,
    this.receiptPath,
    this.receiptUrl,
    this.status = PaymentStatus.pending,
    required this.requestDate,
    this.approvedDate,
    this.approvedBy,
    this.notes,
    this.rejectReason,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'memberId': memberId,
      'loanId': loanId,
      'type': type.name,
      'amount': amount,
      'receiptPath': receiptPath,
      'receiptUrl': receiptUrl,
      'status': status.name,
      'requestDate': requestDate.toIso8601String(),
      'approvedDate': approvedDate?.toIso8601String(),
      'approvedBy': approvedBy,
      'notes': notes,
      'rejectReason': rejectReason,
    };
  }

  factory PaymentRequest.fromMap(Map<String, dynamic> map) {
    return PaymentRequest(
      id: map['id'],
      memberId: map['memberId'] ?? '',
      loanId: map['loanId'],
      type: PaymentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PaymentType.contribution,
      ),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      receiptPath: map['receiptPath'],
      receiptUrl: map['receiptUrl'],
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PaymentStatus.pending,
      ),
      requestDate: parseFirestoreDate(map['requestDate']),
      approvedDate: parseFirestoreDateOrNull(map['approvedDate']),
      approvedBy: map['approvedBy'],
      notes: map['notes'],
      rejectReason: map['rejectReason'],
    );
  }
}
