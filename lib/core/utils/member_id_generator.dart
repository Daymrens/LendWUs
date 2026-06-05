import 'package:cloud_firestore/cloud_firestore.dart';

class MemberIdGenerator {
  static const String prefix = 'LWS';
  static const int padding = 6;
  static const String counterDocPath = 'meta/member_counter';

  static String formatMemberId(int number) {
    if (number < 1) {
      throw ArgumentError.value(number, 'number', 'MemberID number must be >= 1');
    }
    if (number > 999999) {
      throw ArgumentError.value(number, 'number', 'MemberID number exceeds 6 digits (max 999999)');
    }
    return '$prefix${number.toString().padLeft(padding, '0')}';
  }

  static int? parseMemberId(String? value) {
    if (value == null) return null;
    if (!value.startsWith(prefix)) return null;
    final tail = value.substring(prefix.length);
    return int.tryParse(tail);
  }

  static int maxExistingNumber(Iterable<String?> memberIds) {
    int maxN = 0;
    for (final id in memberIds) {
      final n = parseMemberId(id);
      if (n != null && n > maxN) maxN = n;
    }
    return maxN;
  }

  static Future<String> generateNextMemberId(FirebaseFirestore db) async {
    final ids = await generateNextMemberIds(db, 1);
    return ids.first;
  }

  static Future<List<String>> generateNextMemberIds(FirebaseFirestore db, int count) async {
    if (count <= 0) return [];
    return db.runTransaction((tx) async {
      final counterRef = db.doc(counterDocPath);
      final counter = await tx.get(counterRef);
      final existingMax = (counter.data()?['lastNumber'] as int?) ?? 0;

      final start = existingMax + 1;
      final end = start + count - 1;
      if (end > 999999) {
        throw StateError('MemberID limit reached (max 999999)');
      }

      tx.set(counterRef, {'lastNumber': end, 'updatedAt': FieldValue.serverTimestamp()});
      return List<String>.generate(count, (i) => formatMemberId(start + i));
    });
  }

  static Future<int> backfillMissingMemberIds(FirebaseFirestore db) async {
    final snap = await db.collection('members').get();
    final missing = snap.docs
        .where((d) => (d.data()['memberId'] as String?) == null)
        .toList()
      ..sort((a, b) {
        final aTs = (a.data()['joinedAt'] as String?) ?? '';
        final bTs = (b.data()['joinedAt'] as String?) ?? '';
        return aTs.compareTo(bTs);
      });

    if (missing.isEmpty) return 0;

    int cursor = maxExistingNumber(snap.docs.map((d) => d.data()['memberId'] as String?));
    final batch = db.batch();
    for (final doc in missing) {
      cursor += 1;
      batch.update(doc.reference, {'memberId': formatMemberId(cursor)});
    }
    batch.set(db.doc(counterDocPath), {
      'lastNumber': cursor,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return missing.length;
  }
}
