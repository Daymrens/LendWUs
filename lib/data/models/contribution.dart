class Contribution {
  String? id;
  String memberId;
  double amount;
  DateTime date;
  int month;
  int year;
  String? notes;

  Contribution({
    this.id,
    required this.memberId,
    required this.amount,
    required this.date,
    required this.month,
    required this.year,
    this.notes,
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
    };
  }

  factory Contribution.fromMap(Map<String, dynamic> map) {
    return Contribution(
      id: map['id'],
      memberId: map['memberId'],
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] is DateTime
          ? map['date']
          : DateTime.parse(map['date']),
      month: map['month'],
      year: map['year'],
      notes: map['notes'],
    );
  }
}
