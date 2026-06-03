import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contribution.dart';
import '../../core/firebase/firebase_service.dart';

class ContributionRepository {
  Future<String> createContribution(Contribution contribution) async {
    final docRef = await FirebaseService.firestore
        .collection('contributions')
        .add(contribution.toMap());
    return docRef.id;
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

  Future<List<Contribution>> getAllContributions() async {
    final snapshot = await FirebaseService.firestore
        .collection('contributions')
        .orderBy('date', descending: true)
        .get();
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
}
