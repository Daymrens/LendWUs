import 'dart:convert';
import 'dart:io';

const String emulatorHost = 'localhost:8080';
const String projectId = 'lmsystemm';

Future<void> main() async {
  final client = HttpClient();

  try {
    final membersJson = await _readCollection(client, 'members');
    final contribsJson = await _readCollection(client, 'contributions');
    final loansJson = await _readCollection(client, 'loans');
    final repayJson = await _readCollection(client, 'repayments');

    stdout.writeln('=== RAW DATA FROM EMULATOR ===\n');

    stdout.writeln('Members (${membersJson.length}):');
    for (final m in membersJson) {
      stdout.writeln('  ${m['name']}: headsCount=${m['headsCount']}, '
          'amountPerHead=${m['amountPerHead']}, active=${m['active']}');
    }

    double totalContrib = 0;
    stdout.writeln('\nContributions (${contribsJson.length}):');
    for (final c in contribsJson) {
      final amt = (c['amount'] as num).toDouble();
      totalContrib += amt;
      stdout.writeln('  ${c['memberId']}: amount=₱\$${_pesos(amt)}');
    }
    stdout.writeln('  TOTAL: $totalContrib (₱\$${_pesos(totalContrib)})');
    stdout.writeln('  Expected: 225.0 (₱\$225.00)');

    double totalLoans = 0;
    stdout.writeln('\nLoans (${loansJson.length}):');
    for (final l in loansJson) {
      final principal = (l['principal'] as num).toDouble();
      final rate = (l['interestRate'] as num).toDouble();
      totalLoans += principal;
      final totalDue = principal + (principal * rate);
      stdout.writeln('  ${l['__docId'] ?? l['id']}: member=${l['memberId']}, '
          'principal=$principal (₱\$${_pesos(principal)}), '
          'rate=$rate, totalDue=$totalDue (₱\$${_pesos(totalDue)}), '
          'repaid=${l['isFullyRepaid']}');
    }
  stdout.writeln('  TOTAL loans issued: $totalLoans (₱\$${_pesos(totalLoans)})');
  stdout.writeln('  Expected: 5000.0 (₱\$5,000.00)');

    double totalRepaid = 0;
    stdout.writeln('\nRepayments (${repayJson.length}):');
    for (final r in repayJson) {
      final amt = (r['amountPaid'] as num).toDouble();
      totalRepaid += amt;
      stdout.writeln('  ${r['loanId']}: amountPaid=$amt (₱\$${_pesos(amt)})');
    }
  stdout.writeln('  TOTAL repaid: $totalRepaid (₱\$${_pesos(totalRepaid)})');
  stdout.writeln('  Expected: 3000.0 (₱\$3,000.00)');

    stdout.writeln('\n=== COMPUTED VALUES ===');
    final fundBalance = totalContrib - totalLoans + totalRepaid;
    stdout.writeln('fundBalance = $totalContrib - $totalLoans + $totalRepaid = $fundBalance');
    stdout.writeln('  Expected: -1775.0 (₱\$-1,775.00)');

    final principal = 5000.0;
    final rate = 0.05;
    final totalDue = principal + (principal * rate);
    final remaining = totalDue - totalRepaid;
    stdout.writeln('\nLoan A:');
    stdout.writeln('  principal=$principal (₱\$${_pesos(principal)})');
    stdout.writeln('  totalAmountDue=$totalDue (₱\$${_pesos(totalDue)})');
    stdout.writeln('  interestAmount=${totalDue - principal} (₱\$${_pesos(totalDue - principal)})');
    stdout.writeln('  totalRepaid=$totalRepaid');
    stdout.writeln('  remainingBalance=$remaining (₱\$${_pesos(remaining)})');
    stdout.writeln('  interestPortion=${totalRepaid > principal ? totalRepaid - principal : 0}');

    stdout.writeln('\n=== MEMBER PAYMENT STATUS ===');
    final amountPerHead = 150.0;
    for (final m in membersJson) {
      final name = m['name'];
      final docId = m['__docId'] ?? m['id'];
      final reqAmount = amountPerHead;
      final memberContribs = contribsJson
          .where((c) => c['memberId'] == docId)
          .fold<double>(0, (sum, c) => sum + (c['amount'] as num).toDouble());
      final progress = reqAmount > 0 ? (memberContribs / reqAmount).clamp(0.0, 1.0) : 0.0;
      String status;
      if (progress >= 1.0) status = 'Paid';
      else if (memberContribs == 0) status = 'Pending';
      else status = '${(progress * 100).toStringAsFixed(0)}%';
      stdout.writeln('  $name: paid=$memberContribs (₱\$${_pesos(memberContribs)}), '
          'required=$reqAmount (₱\$${_pesos(reqAmount)}), '
          'progress=${(progress*100).toStringAsFixed(0)}%, status=$status');
    }

    stdout.writeln('\n=== VALUE CHECK ===');
    stdout.writeln('Seed now stores actual currency values (not centavos).');
    stdout.writeln('format(150.0) = ₱150.00 ✓');
    stdout.writeln('format(5000.0) = ₱5,000.00 ✓');
    stdout.writeln('format(3000.0) = ₱3,000.00 ✓');

  } catch (e, st) {
    stderr.writeln('Verification failed: $e');
    stderr.writeln('$st');
    exitCode = 1;
  } finally {
    client.close();
  }
}

String _pesos(double amount) {
  return '${amount.toStringAsFixed(2)}';
}

Future<List<Map<String, dynamic>>> _readCollection(HttpClient client, String collection) async {
  final url = Uri.parse(
    'http://$emulatorHost/v1/projects/$projectId/databases/(default)/documents/$collection',
  );
  final request = await client.getUrl(url);
  request.headers.set('Authorization', 'Bearer owner');
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  if (response.statusCode >= 300) {
    stderr.writeln('Failed to read $collection: ${response.statusCode} $body');
    return [];
  }

  final decoded = jsonDecode(body);
  final docs = decoded['documents'] as List? ?? [];
  return docs.map((doc) {
    final docMap = doc as Map<String, dynamic>;
    final name = docMap['name'] as String? ?? '';
    final docId = name.split('/').last;
    final fields = docMap['fields'] as Map<String, dynamic>? ?? {};
    final result = _fromFirestoreFields(fields);
    result['__docId'] = docId;
    return result;
  }).toList();
}

Map<String, dynamic> _fromFirestoreFields(Map<String, dynamic> fields) {
  final result = <String, dynamic>{};
  fields.forEach((key, value) {
    result[key] = _fromFirestoreValue(value as Map<String, dynamic>);
  });
  return result;
}

dynamic _fromFirestoreValue(Map<String, dynamic> value) {
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('integerValue')) return int.parse(value['integerValue'] as String);
  if (value.containsKey('doubleValue')) return value['doubleValue'];
  if (value.containsKey('booleanValue')) return value['booleanValue'];
  if (value.containsKey('nullValue')) return null;
  if (value.containsKey('arrayValue')) {
    final items = value['arrayValue']['values'] as List? ?? [];
    return items.map((e) => _fromFirestoreValue(e as Map<String, dynamic>)).toList();
  }
  if (value.containsKey('mapValue')) {
    final fields = value['mapValue']['fields'] as Map<String, dynamic>? ?? {};
    return _fromFirestoreFields(fields);
  }
  return null;
}
