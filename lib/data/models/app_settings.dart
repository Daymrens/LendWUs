class AppSettings {
  final double minPaymentPerHead;
  final double maxPaymentPerHead;
  final double loanInterestPercent;
  final String currencySymbol;
  final String currencyCode;

  AppSettings({
    required this.minPaymentPerHead,
    required this.maxPaymentPerHead,
    required this.loanInterestPercent,
    required this.currencySymbol,
    required this.currencyCode,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      minPaymentPerHead: (map['minPaymentPerHead'] ?? 0.0).toDouble(),
      maxPaymentPerHead: (map['maxPaymentPerHead'] ?? 1000.0).toDouble(),
      loanInterestPercent: (map['loanInterestPercent'] ?? 10.0).toDouble(),
      currencySymbol: map['currencySymbol'] ?? '\u20B1',
      currencyCode: map['currencyCode'] ?? 'PHP',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minPaymentPerHead': minPaymentPerHead,
      'maxPaymentPerHead': maxPaymentPerHead,
      'loanInterestPercent': loanInterestPercent,
      'currencySymbol': currencySymbol,
      'currencyCode': currencyCode,
    };
  }

  AppSettings copyWith({
    double? minPaymentPerHead,
    double? maxPaymentPerHead,
    double? loanInterestPercent,
    String? currencySymbol,
    String? currencyCode,
  }) {
    return AppSettings(
      minPaymentPerHead: minPaymentPerHead ?? this.minPaymentPerHead,
      maxPaymentPerHead: maxPaymentPerHead ?? this.maxPaymentPerHead,
      loanInterestPercent: loanInterestPercent ?? this.loanInterestPercent,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
