import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firebase_service.dart';
import '../models/returns_info.dart';

class ReturnsRepository {
  final FirebaseFirestore _firestore = FirebaseService.firestore;

  Stream<ReturnsInfo> watchReturns() {
    return _firestore.collection('returns').doc('current').snapshots().map((doc) {
      if (!doc.exists) {
        return ReturnsInfo(totalReturns: 0.0, totalHeads: 0, perHeadShare: 0.0);
      }
      return ReturnsInfo.fromMap(doc.data()!);
    });
  }

  Future<void> saveReturns(ReturnsInfo info) async {
    await _firestore.collection('returns').doc('current').set(info.toMap());
  }
}
