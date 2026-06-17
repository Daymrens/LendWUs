import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contribution.dart';
import '../../core/firebase/firebase_service.dart';

class ContributionRepository {
  static const int _defaultPageSize = 100;

  Future<String> createContribution(Contribution contribution) async {
    final docRef = await FirebaseService.firestore
        .collection('contributions')
        .add(contribution.toMap());
    return docRef.id;
  }

  Future<List<Contribution>> getMemberContributions(String memberId, {int? limit, DocumentSnapshot? startAfter}) async {
    var query = FirebaseService.firestore
        .collection('contributions')
        .where('memberId', isEqualTo: memberId);
    // Omit orderBy — the `date` field may have mixed types (String / Timestamp)
    // between mobile and web clients, causing Firestore queries to fail.
    // Sort client-side if needed.
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    if (limit != null) {
      query = query.limit(limit);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Contribution.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// Fetches all contributions without server-side ordering.
  /// Avoid `orderBy` at the collection level because the `date` field may
  /// contain mixed types (String from Flutter, Timestamp from web).
  /// Sort client-side if needed.
  Future<List<Contribution>> getAllContributions({int? limit, DocumentSnapshot? startAfter}) async {
    Query<Map<String, dynamic>> query = FirebaseService.firestore
        .collection('contributions');
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    if (limit != null) {
      query = query.limit(limit);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Contribution.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<double> getMemberTotalContributions(String memberId) async {
    final snapshot = await FirebaseService.firestore
        .collection('contributions')
        .where('memberId', isEqualTo: memberId)
        .get();
    double total = 0.0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['amount'] as num).toDouble();
    }
    return total;
  }

  Future<void> updateContribution(Contribution contribution) async {
    await FirebaseService.firestore
        .collection('contributions')
        .doc(contribution.id!)
        .update(contribution.toMap());
  }

  Future<void> deleteContribution(String id) async {
    await FirebaseService.firestore
        .collection('contributions')
        .doc(id)
        .delete();
  }

  Stream<List<Contribution>> watchAllContributions() {
    return FirebaseService.firestore
        .collection('contributions')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Contribution.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Like [watchAllContributions] but ordered by date descending.
  /// Avoid using [watchAllContributions] with `orderBy` at the collection level
  /// if some documents store `date` as a String (Flutter) and others as a
  /// Timestamp (web) — Firestore refuses to order across mixed types.
  /// Use this when the UI needs sorted data and sort client-side as a fallback,
  /// or migrate all `date` values to a single type.
  Stream<List<Contribution>> watchAllContributionsOrdered() {
    return FirebaseService.firestore
        .collection('contributions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Contribution.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<Contribution>> watchMemberContributions(String memberId) {
    return FirebaseService.firestore
        .collection('contributions')
        .where('memberId', isEqualTo: memberId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Contribution.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }
}
