import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String _symbol = '\u20B1';
  static String _locale = 'en_PH';

  static NumberFormat _formatter = NumberFormat.currency(
    symbol: _symbol,
    locale: _locale,
    decimalDigits: 2,
  );

  static void updateConfiguration(String symbol, String code) {
    _symbol = symbol;
    if (code == 'PHP') {
      _locale = 'en_PH';
    } else if (code == 'USD') {
      _locale = 'en_US';
    } else if (code == 'EUR') {
      _locale = 'en_IE';
    } else if (code == 'GBP') {
      _locale = 'en_GB';
    } else if (code == 'JPY') {
      _locale = 'ja_JP';
    } else if (code == 'KRW') {
      _locale = 'ko_KR';
    } else if (code == 'INR') {
      _locale = 'en_IN';
    } else {
      _locale = 'en_US';
    }

    _formatter = NumberFormat.currency(
      symbol: _symbol,
      locale: _locale,
      decimalDigits: 2,
    );
  }

  /// Format centavos (int) to display string.
  /// e.g. 124500 → "₱1,245.00"
  static String format(int centavos) {
    return _formatter.format(centavos / 100);
  }

  /// Alias for [format].
  static String formatCentavos(int centavos) {
    return format(centavos);
  }

  /// Format a double value (non-monetary) to display string.
  /// For currency values, use [format] instead — this is for rates, percentages, etc.
  static String formatDouble(double value) {
    return _formatter.format(value);
  }

  /// Parse display string back to centavos.
  /// Strips non-numeric characters (allowing only the first decimal point).
  /// Returns 0 for invalid or empty input.
  static int parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return 0;
    final firstDot = cleaned.indexOf('.');
    String sanitized;
    if (firstDot == -1) {
      sanitized = cleaned;
    } else {
      sanitized =
          cleaned.substring(0, firstDot + 1) +
          cleaned.substring(firstDot + 1).replaceAll('.', '');
    }
    final value = double.tryParse(sanitized);
    if (value == null) return 0;
    return (value * 100).round();
  }

  /// Convert double to centavos
  static int toCentavos(double amount) {
    return (amount * 100).round();
  }

  /// Convert centavos to double
  static double toDouble(int centavos) {
    return centavos / 100;
  }

  /// The currency symbol used by this formatter
  static String get currencySymbol => _symbol;
}
