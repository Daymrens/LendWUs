import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    symbol: '₱',
    locale: 'fil_PH',
    decimalDigits: 2,
  );

  /// Format centavos (int) to display string
  /// e.g. 1245000 → "₱12,450.00"
  static String formatCentavos(int centavos) {
    return _formatter.format(centavos / 100);
  }

  /// Format double to display string (legacy support)
  static String format(double amount) {
    return _formatter.format(amount);
  }

  /// Parse display string back to centavos
  static int parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[₱,\s]'), '');
    return (double.parse(cleaned) * 100).round();
  }

  /// Convert double to centavos
  static int toCentavos(double amount) {
    return (amount * 100).round();
  }

  /// Convert centavos to double
  static double toDouble(int centavos) {
    return centavos / 100;
  }
}
