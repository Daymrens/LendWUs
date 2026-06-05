import 'package:flutter_test/flutter_test.dart';
import 'package:sinking_fund_app/core/utils/member_id_generator.dart';

void main() {
  group('formatMemberId', () {
    test('pads single digit to 6 digits', () {
      expect(MemberIdGenerator.formatMemberId(1), 'LWS000001');
    });

    test('pads 2-5 digit numbers to 6 digits', () {
      expect(MemberIdGenerator.formatMemberId(10), 'LWS000010');
      expect(MemberIdGenerator.formatMemberId(100), 'LWS000100');
      expect(MemberIdGenerator.formatMemberId(9999), 'LWS009999');
      expect(MemberIdGenerator.formatMemberId(12345), 'LWS012345');
    });

    test('does not pad 6-digit numbers', () {
      expect(MemberIdGenerator.formatMemberId(100000), 'LWS100000');
      expect(MemberIdGenerator.formatMemberId(999999), 'LWS999999');
    });

    test('throws on numbers below 1', () {
      expect(() => MemberIdGenerator.formatMemberId(0), throwsArgumentError);
      expect(() => MemberIdGenerator.formatMemberId(-5), throwsArgumentError);
    });

    test('throws on numbers above 999999', () {
      expect(() => MemberIdGenerator.formatMemberId(1000000), throwsArgumentError);
    });
  });

  group('parseMemberId', () {
    test('parses valid IDs', () {
      expect(MemberIdGenerator.parseMemberId('LWS000001'), 1);
      expect(MemberIdGenerator.parseMemberId('LWS000010'), 10);
      expect(MemberIdGenerator.parseMemberId('LWS123456'), 123456);
      expect(MemberIdGenerator.parseMemberId('LWS999999'), 999999);
    });

    test('returns null for null input', () {
      expect(MemberIdGenerator.parseMemberId(null), isNull);
    });

    test('returns null for missing prefix', () {
      expect(MemberIdGenerator.parseMemberId('ABC000001'), isNull);
      expect(MemberIdGenerator.parseMemberId('000001'), isNull);
      expect(MemberIdGenerator.parseMemberId('lws000001'), isNull);
    });

    test('returns null for non-numeric tail', () {
      expect(MemberIdGenerator.parseMemberId('LWSabcdef'), isNull);
      expect(MemberIdGenerator.parseMemberId('LWS'), isNull);
    });

    test('round-trip format/parse', () {
      for (final n in [1, 2, 50, 100, 1000, 99999, 500000, 999999]) {
        expect(MemberIdGenerator.parseMemberId(MemberIdGenerator.formatMemberId(n)), n);
      }
    });
  });

  group('maxExistingNumber', () {
    test('returns 0 for empty list', () {
      expect(MemberIdGenerator.maxExistingNumber([]), 0);
    });

    test('returns 0 for list with only nulls', () {
      expect(MemberIdGenerator.maxExistingNumber([null, null]), 0);
    });

    test('returns max of valid IDs', () {
      expect(MemberIdGenerator.maxExistingNumber([
        'LWS000001',
        'LWS000005',
        'LWS000003',
        null,
        'LWS000100',
      ]), 100);
    });

    test('ignores malformed IDs', () {
      expect(MemberIdGenerator.maxExistingNumber([
        'LWS000050',
        'BAD123456',
        null,
        'LWS000099',
      ]), 99);
    });
  });
}
