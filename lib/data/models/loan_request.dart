enum LoanRequestStatus { pending, approved, rejected, disbursed }

class LoanRequest {
  String? id;
  String memberId;
  String memberName;
  double amount;
  double interestRate;
  DateTime dueDate;
  LoanRequestStatus status;
  DateTime requestedAt;
  DateTime? processedAt;
  String? notes;
  String? loanId;

  LoanRequest({
    this.id,
    required this.memberId,
    required this.memberName,
    required this.amount,
    this.interestRate = 5.0,
    required this.dueDate,
    this.status = LoanRequestStatus.pending,
    required this.requestedAt,
    this.processedAt,
    this.notes,
    this.loanId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'memberId': memberId,
      'memberName': memberName,
      'amount': amount,
      'interestRate': interestRate,
      'dueDate': dueDate.toIso8601String(),
      'status': status.name,
      'requestedAt': requestedAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'notes': notes,
      'loanId': loanId,
    };
  }

  factory LoanRequest.fromMap(Map<String, dynamic> map) {
    return LoanRequest(
      id: map['id'],
      memberId: map['memberId'],
      memberName: map['memberName'],
      amount: (map['amount'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      dueDate: map['dueDate'] is DateTime
          ? map['dueDate']
          : DateTime.parse(map['dueDate']),
      status: LoanRequestStatus.values.firstWhere((e) => e.name == map['status']),
      requestedAt: map['requestedAt'] is DateTime
          ? map['requestedAt']
          : DateTime.parse(map['requestedAt']),
      processedAt: map['processedAt'] != null
          ? (map['processedAt'] is DateTime
              ? map['processedAt']
              : DateTime.parse(map['processedAt']))
          : null,
      notes: map['notes'],
      loanId: map['loanId'],
    );
  }
}
