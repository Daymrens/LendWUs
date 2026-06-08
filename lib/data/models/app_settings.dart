class AppSettings {
  final double minPaymentPerHead;
  final double maxPaymentPerHead;
  final double loanInterestPercent;
  final String currencySymbol;
  final String currencyCode;
  final int cutoffDay1;
  final int cutoffDay2;
  final int paymentTatHours;
  final List<String> adminEmails;
  final String qrAccountName;
  final String qrAccountNumber;
  final String qrImageUrl;

  AppSettings({
    required this.minPaymentPerHead,
    required this.maxPaymentPerHead,
    required this.loanInterestPercent,
    required this.currencySymbol,
    required this.currencyCode,
    this.cutoffDay1 = 13,
    this.cutoffDay2 = 28,
    this.paymentTatHours = 24,
    this.adminEmails = const [],
    this.qrAccountName = '',
    this.qrAccountNumber = '',
    this.qrImageUrl = '',
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      minPaymentPerHead: (map['minPaymentPerHead'] ?? 0.0).toDouble(),
      maxPaymentPerHead: (map['maxPaymentPerHead'] ?? 1000.0).toDouble(),
      loanInterestPercent: (map['loanInterestPercent'] ?? 10.0).toDouble(),
      currencySymbol: map['currencySymbol'] ?? '\u20B1',
      currencyCode: map['currencyCode'] ?? 'PHP',
      cutoffDay1: map['cutoffDay1'] ?? 13,
      cutoffDay2: map['cutoffDay2'] ?? 28,
      paymentTatHours: map['paymentTatHours'] ?? 24,
      adminEmails: List<String>.from(map['adminEmails'] ?? []),
      qrAccountName: map['qrAccountName'] ?? '',
      qrAccountNumber: map['qrAccountNumber'] ?? '',
      qrImageUrl: map['qrImageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minPaymentPerHead': minPaymentPerHead,
      'maxPaymentPerHead': maxPaymentPerHead,
      'loanInterestPercent': loanInterestPercent,
      'currencySymbol': currencySymbol,
      'currencyCode': currencyCode,
      'cutoffDay1': cutoffDay1,
      'cutoffDay2': cutoffDay2,
      'paymentTatHours': paymentTatHours,
      'adminEmails': adminEmails,
      'qrAccountName': qrAccountName,
      'qrAccountNumber': qrAccountNumber,
      'qrImageUrl': qrImageUrl,
    };
  }

  AppSettings copyWith({
    double? minPaymentPerHead,
    double? maxPaymentPerHead,
    double? loanInterestPercent,
    String? currencySymbol,
    String? currencyCode,
    int? cutoffDay1,
    int? cutoffDay2,
    int? paymentTatHours,
    List<String>? adminEmails,
    String? qrAccountName,
    String? qrAccountNumber,
    String? qrImageUrl,
  }) {
    return AppSettings(
      minPaymentPerHead: minPaymentPerHead ?? this.minPaymentPerHead,
      maxPaymentPerHead: maxPaymentPerHead ?? this.maxPaymentPerHead,
      loanInterestPercent: loanInterestPercent ?? this.loanInterestPercent,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      cutoffDay1: cutoffDay1 ?? this.cutoffDay1,
      cutoffDay2: cutoffDay2 ?? this.cutoffDay2,
      paymentTatHours: paymentTatHours ?? this.paymentTatHours,
      adminEmails: adminEmails ?? this.adminEmails,
      qrAccountName: qrAccountName ?? this.qrAccountName,
      qrAccountNumber: qrAccountNumber ?? this.qrAccountNumber,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
    );
  }
}
