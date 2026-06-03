import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contribution.dart';
import '../../core/firebase/firebase_service.dart';

class FundRepository {
  Future<List<Contribution>> getAllContributions() async {
    final snapshot = await FirebaseService.firestore
        .collection('contributions')
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Contribution.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<Contribution>> getContributionsByMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1).toIso8601String();
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59).toIso8601String();
    final snapshot = await FirebaseService.firestore
        .collection('contributions')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .get();
    return snapshot.docs
        .map((doc) => Contribution.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<String> addContribution(Contribution contribution) async {
    final docRef = await FirebaseService.firestore
        .collection('contributions')
        .add(contribution.toMap());
    return docRef.id;
  }

  Future<double> getTotalFund() async {
    final contributions = await getAllContributions();
    return contributions.fold<double>(0.0, (sum, c) => sum + c.amount);
  }

  Future<List<Contribution>> getMemberContributions(String memberId) async {
    final snapshot = await FirebaseService.firestore
        .collection('contributions')
        .where('memberId', isEqualTo: memberId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Contribution.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<double> getMemberTotalContributions(String memberId) async {
    final contributions = await getMemberContributions(memberId);
    return contributions.fold<double>(0.0, (sum, c) => sum + c.amount);
  }
}
