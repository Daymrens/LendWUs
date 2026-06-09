import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contribution.dart';
import 'member_repository.dart';
import '../../core/firebase/firebase_service.dart';

class ContributionRepository {
  Future<String> createContribution(Contribution contribution, {Transaction? transaction}) async {
    final ref = FirebaseService.firestore.collection('contributions').doc();
    if (transaction != null) {
      transaction.set(ref, contribution.toMap());
      return ref.id;
    } else {
      await ref.set(contribution.toMap());
      return ref.id;
    }
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

  Future<void> updateContribution(Contribution contribution) async {
    await FirebaseService.firestore
        .collection('contributions')
        .doc(contribution.id!)
        .update(contribution.toMap());
    
    // Reconcile member balance
    final memberRepo = MemberRepository();
    await memberRepo.reconcileMemberMonth(
      contribution.memberId,
      contribution.month,
      contribution.year,
    );
  }

  Future<void> deleteContribution(String id) async {
    final firestore = FirebaseService.firestore;
    final doc = await firestore.collection('contributions').doc(id).get();
    if (!doc.exists) return;
    
    final contribution = Contribution.fromMap({...doc.data()!, 'id': doc.id});
    await firestore.collection('contributions').doc(id).delete();
    
    // Reconcile member balance
    final memberRepo = MemberRepository();
    await memberRepo.reconcileMemberMonth(
      contribution.memberId,
      contribution.month,
      contribution.year,
    );
  }

  Stream<List<Contribution>> watchAllContributions() {
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
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Contribution.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }
}
