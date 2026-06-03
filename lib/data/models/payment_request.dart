enum PaymentStatus { pending, approved, rejected }
enum PaymentType { contribution, loan }

class PaymentRequest {
  String? id;
  String memberId;
  PaymentType type;
  double amount;
  String? receiptPath;
  PaymentStatus status;
  DateTime requestDate;
  DateTime? approvedDate;
  String? approvedBy;
  String? notes;
  String? rejectReason;

  PaymentRequest({
    this.id,
    required this.memberId,
    required this.type,
    required this.amount,
    this.receiptPath,
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
      'type': type.name,
      'amount': amount,
      'receiptPath': receiptPath,
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
      memberId: map['memberId'],
      type: PaymentType.values.firstWhere((e) => e.name == map['type']),
      amount: (map['amount'] as num).toDouble(),
      receiptPath: map['receiptPath'],
      status: PaymentStatus.values.firstWhere((e) => e.name == map['status']),
      requestDate: map['requestDate'] is DateTime
          ? map['requestDate']
          : DateTime.parse(map['requestDate']),
      approvedDate: map['approvedDate'] != null
          ? (map['approvedDate'] is DateTime
              ? map['approvedDate']
              : DateTime.parse(map['approvedDate']))
          : null,
      approvedBy: map['approvedBy'],
      notes: map['notes'],
      rejectReason: map['rejectReason'],
    );
  }
}
