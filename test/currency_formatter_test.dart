import 'package:flutter_test/flutter_test.dart';
import 'package:sinking_fund_app/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.parse', () {
    setUp(() {
      CurrencyFormatter.updateConfiguration('\u20B1', 'PHP');
    });

    test('parses whole number', () {
      expect(CurrencyFormatter.parse('100'), 10000);
    });

    test('parses decimal number', () {
      expect(CurrencyFormatter.parse('100.50'), 10050);
    });

    test('strips currency symbol', () {
      expect(CurrencyFormatter.parse('\u20B11,500.00'), 150000);
    });

    test('handles thousands separator', () {
      expect(CurrencyFormatter.parse('1,234,567.89'), 123456789);
    });

    test('returns 0 for empty', () {
      expect(CurrencyFormatter.parse(''), 0);
    });

    test('returns 0 for whitespace only', () {
      expect(CurrencyFormatter.parse('   '), 0);
    });

    test('returns 0 for non-numeric', () {
      expect(CurrencyFormatter.parse('abc'), 0);
    });

    test('does not crash on multiple decimal points', () {
      // This is the bug case - previously crashed with FormatException
      expect(CurrencyFormatter.parse('1.2.3'), isNot(throwsA(isA<FormatException>())));
    });

    test('rounds to nearest cent', () {
      expect(CurrencyFormatter.parse('100.555'), 10056);
    });

    test('handles leading/trailing whitespace', () {
      expect(CurrencyFormatter.parse('  150.00  '), 15000);
    });
  });

  group('CurrencyFormatter.toCentavos / toDouble', () {
    test('round trip', () {
      final centavos = CurrencyFormatter.toCentavos(123.45);
      expect(centavos, 12345);
      expect(CurrencyFormatter.toDouble(centavos), 123.45);
    });

    test('rounds half-up', () {
      expect(CurrencyFormatter.toCentavos(0.005), 1);
      expect(CurrencyFormatter.toCentavos(0.004), 0);
    });
  });

  group('CurrencyFormatter.format', () {
    test('formats PHP', () {
      CurrencyFormatter.updateConfiguration('\u20B1', 'PHP');
      expect(CurrencyFormatter.format(1500.00), contains('1,500.00'));
    });

    test('formats USD', () {
      CurrencyFormatter.updateConfiguration('\$', 'USD');
      expect(CurrencyFormatter.format(1500.00), contains('1,500.00'));
    });

    test('formats EUR', () {
      CurrencyFormatter.updateConfiguration('€', 'EUR');
      expect(CurrencyFormatter.format(1500.00), contains('1,500.00'));
    });
  });

  group('CurrencyFormatter.formatCentavos', () {
    test('formats integer centavos', () {
      expect(CurrencyFormatter.formatCentavos(1245000), contains('12,450.00'));
    });
  });
}
