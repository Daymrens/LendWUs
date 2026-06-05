import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sinking_fund_app/core/utils/firestore_helpers.dart';

void main() {
  group('parseFirestoreDate', () {
    test('null returns fallback (now when not provided)', () {
      final before = DateTime.now();
      final result = parseFirestoreDate(null);
      final after = DateTime.now();
      expect(result.isBefore(after), isTrue);
      expect(!result.isBefore(before), isTrue);
    });

    test('null with explicit fallback returns the fallback', () {
      final fb = DateTime(2026, 1, 1);
      expect(parseFirestoreDate(null, fallback: fb), fb);
    });

    test('DateTime passes through', () {
      final dt = DateTime(2026, 6, 15, 10, 30);
      expect(parseFirestoreDate(dt), dt);
    });

    test('Timestamp converts to DateTime via toDate()', () {
      final ts = Timestamp.fromDate(DateTime(2026, 6, 15, 10, 30));
      final result = parseFirestoreDate(ts);
      expect(result, DateTime(2026, 6, 15, 10, 30));
    });

    test('ISO 8601 string parses', () {
      expect(
        parseFirestoreDate('2026-06-15T10:30:00.000Z'),
        DateTime.utc(2026, 6, 15, 10, 30),
      );
    });

    test('int (millis since epoch) parses', () {
      final ms = DateTime(2026, 6, 15).millisecondsSinceEpoch;
      final result = parseFirestoreDate(ms);
      expect(result.millisecondsSinceEpoch, ms);
    });

    test('unrecognized type returns fallback', () {
      final fb = DateTime(2026, 1, 1);
      expect(parseFirestoreDate(3.14, fallback: fb), fb);
    });
  });

  group('parseFirestoreDateOrNull', () {
    test('null returns null', () {
      expect(parseFirestoreDateOrNull(null), isNull);
    });

    test('DateTime passes through', () {
      final dt = DateTime(2026, 6, 15);
      expect(parseFirestoreDateOrNull(dt), dt);
    });

    test('Timestamp converts to DateTime via toDate()', () {
      final ts = Timestamp.fromDate(DateTime(2026, 6, 15));
      expect(parseFirestoreDateOrNull(ts), DateTime(2026, 6, 15));
    });

    test('ISO 8601 string parses', () {
      expect(
        parseFirestoreDateOrNull('2026-06-15T10:30:00.000Z'),
        DateTime.utc(2026, 6, 15, 10, 30),
      );
    });

    test('unrecognized type returns null', () {
      expect(parseFirestoreDateOrNull(3.14), isNull);
    });
  });
}
