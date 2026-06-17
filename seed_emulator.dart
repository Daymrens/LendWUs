// scripts/seed_emulator.dart
//
// Seeds the Firestore emulator with a known set of members, contributions,
// loans, and repayments matching the worked examples / formulas in
// sinking_fund_logic.md. Use this to get a reproducible starting state
// when debugging fund balance, loan, repayment, or returns calculations.
//
// USAGE:
//   1. Start the emulator (in another terminal):
//        firebase emulators:start --only firestore,auth
//
//   2. Run this script:
//        dart run scripts/seed_emulator.dart
//
//   Or run emulator + script together, auto-shutdown after:
//        firebase emulators:exec --only firestore "dart run scripts/seed_emulator.dart"
//
// This script talks to the Firestore emulator over its REST API, so it
// does NOT require a Firebase service account or real credentials.
// Adjust FIRESTORE_EMULATOR_HOST / PROJECT_ID below if your firebase.json
// configures a non-default port or project ID.

import 'dart:convert';
import 'dart:io';

// ── Config ──────────────────────────────────────────────────────────────

const String emulatorHost = 'localhost:8080'; // match firebase.json "firestore.port"
const String projectId = 'lmsystemm'; // matches .firebaserc

// NOTE: The app stores monetary values as doubles (actual currency amounts),
// NOT centavos. All models use double, formatted via CurrencyFormatter.format().

// ── Seed data ───────────────────────────────────────────────────────────
//
// Scenario:
//   - 3 members, each with 1 head, ₱150.00/head/month (150.0)
//   - Member A has paid their full contribution this month
//   - Member B has paid half
//   - Member C has paid nothing (status should be "Pending")
//   - A loan of ₱5,000.00 (5000.0) issued to Member A at 5% interest
//     -> totalAmountDue = 5000 + (5000 * 0.05) = 5250
//   - A partial repayment of ₱3,000.00 (3000.0) on that loan
//     -> remainingBalance = 5250 - 3000 = 2250 (loan stays open)
//     -> interestPortion = 0 (totalRepaid <= principal, no excess yet)

final members = [
  {
    'id': 'member_a',
    'name': 'Member A',
    'headsCount': 1,
    'amountPerHead': 150.0, // ₱150.00
    'linkedEmail': 'membera@example.com',
    'isActive': true,
  },
  {
    'id': 'member_b',
    'name': 'Member B',
    'headsCount': 1,
    'amountPerHead': 150.0,
    'linkedEmail': 'memberb@example.com',
    'isActive': true,
  },
  {
    'id': 'member_c',
    'name': 'Member C',
    'headsCount': 1,
    'amountPerHead': 150.0,
    'linkedEmail': 'memberc@example.com',
    'isActive': true,
  },
];

DateTime now = DateTime.now();

final contributions = [
  {
    'id': 'contrib_a_full',
    'memberId': 'member_a',
    'amount': 150.0, // full ₱150.00 -> "Paid"
    'date': now.toIso8601String(),
  },
  {
    'id': 'contrib_b_half',
    'memberId': 'member_b',
    'amount': 75.0, // half of ₱150.00 -> "50%"
    'date': now.toIso8601String(),
  },
  // member_c: no contribution doc -> "Pending"
];

final loans = [
  {
    'id': 'loan_a_1',
    'memberId': 'member_a',
    'principal': 5000.0, // ₱5,000.00
    'interestRate': 0.05, // 5% simple interest
    'issuedDate': now.subtract(const Duration(days: 10)).toIso8601String(),
    'dueDate': now.add(const Duration(days: 50)).toIso8601String(),
    'isFullyRepaid': false,
  },
];

final repayments = [
  {
    'id': 'repay_a_1_partial',
    'loanId': 'loan_a_1',
    'amountPaid': 3000.0, // ₱3,000.00 partial repayment
    'date': now.subtract(const Duration(days: 2)).toIso8601String(),
  },
];

// app_settings/fund_settings — needed for isAdmin() rule checks
final appSettings = {
  'id': 'fund_settings',
  'adminEmails': ['daymrens@gmail.com'],
  'currency': 'PHP',
  'loanInterestRate': 0.05,
  'paymentLimit': 10000.0, // ₱10,000.00
};

// ── Expected values (for manual verification) ──────────────────────────
//
// Run the app/provider logic against this seeded data and confirm:
//
//   totalContributions   = 150 + 75                    = 225
//   totalLoansIssued     = 5000
//   totalRepayments      = 3000
//   fundBalance          = 225 - 5000 + 3000           = -1775
//
//   loan_a_1.totalAmountDue   = 5000 + (5000*0.05)    = 5250
//   loan_a_1.interestAmount   = 250
//   loan_a_1.totalRepaid      = 3000
//   loan_a_1.remainingBalance = 5250 - 3000           = 2250
//   loan_a_1.isFullyRepaid    = false
//   loan_a_1.interestPortion  = 0  (3000 <= 5000 principal, no excess yet)
//
//   Member A payment status: "Paid"   (150/150 = 100%)
//   Member B payment status: "50%"    (75/150 = 50%)
//   Member C payment status: "Pending" (0/150)
//
// NOTE: fundBalance is intentionally negative in this scenario to exercise
// the "fund balance goes negative -> block loan issuance" edge case from
// sinking_fund_logic.md §11. If you need a positive-balance scenario,
// adjust contributions/loan principal accordingly.

// ── Implementation ──────────────────────────────────────────────────────

Future<void> main() async {
  final client = HttpClient();

  stdout.writeln('Seeding Firestore emulator at $emulatorHost (project: $projectId)...');

  try {
    for (final member in members) {
      await _writeDoc(client, 'members', member['id'] as String, {
        'name': member['name'],
        'headsCount': member['headsCount'],
        'amountPerHead': member['amountPerHead'],
        'linkedEmail': member['linkedEmail'],
        'isActive': member['isActive'],
      });
    }
    stdout.writeln('  members: ${members.length} written');

    for (final c in contributions) {
      await _writeDoc(client, 'contributions', c['id'] as String, {
        'memberId': c['memberId'],
        'amount': c['amount'],
        'date': c['date'],
      });
    }
    stdout.writeln('  contributions: ${contributions.length} written');

    for (final l in loans) {
      await _writeDoc(client, 'loans', l['id'] as String, {
        'memberId': l['memberId'],
        'principal': l['principal'],
        'interestRate': l['interestRate'],
        'issuedDate': l['issuedDate'],
        'dueDate': l['dueDate'],
        'isFullyRepaid': l['isFullyRepaid'],
      });
    }
    stdout.writeln('  loans: ${loans.length} written');

    for (final r in repayments) {
      await _writeDoc(client, 'repayments', r['id'] as String, {
        'loanId': r['loanId'],
        'amountPaid': r['amountPaid'],
        'date': r['date'],
      });
    }
    stdout.writeln('  repayments: ${repayments.length} written');

    await _writeDoc(client, 'app_settings', appSettings['id'] as String, {
      'adminEmails': appSettings['adminEmails'],
      'currency': appSettings['currency'],
      'loanInterestRate': appSettings['loanInterestRate'],
      'paymentLimit': appSettings['paymentLimit'],
    });
    stdout.writeln('  app_settings: 1 written');

    stdout.writeln('Done. See expected-values comments in this script for verification.');
  } catch (e) {
    stderr.writeln('Seed failed: $e');
    stderr.writeln('Is the Firestore emulator running on $emulatorHost?');
    exitCode = 1;
  } finally {
    client.close();
  }
}

/// Writes a document to the Firestore emulator via its REST API using
/// PATCH (create-or-overwrite), so the script is safely re-runnable.
Future<void> _writeDoc(
  HttpClient client,
  String collection,
  String docId,
  Map<String, dynamic> fields,
) async {
  final url = Uri.parse(
    'http://$emulatorHost/v1/projects/$projectId/databases/(default)/documents/$collection/$docId',
  );

  final body = jsonEncode({'fields': _toFirestoreFields(fields)});

  final request = await client.patchUrl(url);
  request.headers.contentType = ContentType.json;
  request.headers.set('Authorization', 'Bearer owner');
  request.write(body);

  final response = await request.close();
  if (response.statusCode >= 300) {
    final responseBody = await response.transform(utf8.decoder).join();
    throw Exception(
      'Failed to write $collection/$docId: ${response.statusCode} $responseBody',
    );
  }
  await response.drain();
}

/// Converts a plain Dart map into Firestore REST API "Value" wire format.
Map<String, dynamic> _toFirestoreFields(Map<String, dynamic> fields) {
  return fields.map((key, value) => MapEntry(key, _toFirestoreValue(value)));
}

dynamic _toFirestoreValue(dynamic value) {
  if (value == null) return {'nullValue': null};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is String) return {'stringValue': value};
  if (value is List) {
    return {
      'arrayValue': {'values': value.map(_toFirestoreValue).toList()}
    };
  }
  if (value is Map) {
    return {
      'mapValue': {'fields': _toFirestoreFields(value.cast<String, dynamic>())}
    };
  }
  throw Exception('Unsupported value type: ${value.runtimeType}');
}
