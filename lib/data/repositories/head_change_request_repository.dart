import '../models/head_change_request.dart';
import '../models/member.dart';
import 'member_repository.dart';
import '../../core/firebase/firebase_service.dart';

class HeadChangeRequestRepository {
  Future<String> createHeadChangeRequest(HeadChangeRequest request) async {
    final docRef = await FirebaseService.firestore
        .collection('head_change_requests')
        .add(request.toMap());
    return docRef.id;
  }

  Future<List<HeadChangeRequest>> getAllHeadChangeRequests() async {
    final snapshot = await FirebaseService.firestore
        .collection('head_change_requests')
        .orderBy('requestedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => HeadChangeRequest.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<HeadChangeRequest>> getPendingHeadChangeRequests() async {
    final snapshot = await FirebaseService.firestore
        .collection('head_change_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => HeadChangeRequest.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<List<HeadChangeRequest>> getHeadChangeRequestsByMember(String memberId) async {
    final snapshot = await FirebaseService.firestore
        .collection('head_change_requests')
        .where('memberId', isEqualTo: memberId)
        .orderBy('requestedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => HeadChangeRequest.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Stream<List<HeadChangeRequest>> watchAllHeadChangeRequests() {
    return FirebaseService.firestore
        .collection('head_change_requests')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HeadChangeRequest.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<HeadChangeRequest>> watchPendingHeadChangeRequests() {
    return FirebaseService.firestore
        .collection('head_change_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HeadChangeRequest.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<HeadChangeRequest>> watchMemberHeadChangeRequests(String memberId) {
    return FirebaseService.firestore
        .collection('head_change_requests')
        .where('memberId', isEqualTo: memberId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => HeadChangeRequest.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> approveHeadChangeRequest(String requestId, {String? processedBy, String? notes}) async {
    final request = await getRequestById(requestId);
    if (request == null) return;

    await FirebaseService.firestore
        .collection('head_change_requests')
        .doc(requestId)
        .update({
      'status': 'approved',
      'processedAt': DateTime.now().toIso8601String(),
      'processedBy': processedBy,
      'notes': notes,
    });

    final memberRepo = MemberRepository();
    final memberDoc = await FirebaseService.firestore
        .collection('members')
        .doc(request.memberId)
        .get();

    if (memberDoc.exists) {
      final member = Member.fromMap({...memberDoc.data()!, 'id': memberDoc.id});
      member.headsCount = request.requestedHeads;
      member.totalRequired = member.headsCount * member.amountPerHead;
      await memberRepo.updateMember(member);
    }
  }

  Future<void> rejectHeadChangeRequest(String requestId, {String? processedBy, String? notes}) async {
    await FirebaseService.firestore
        .collection('head_change_requests')
        .doc(requestId)
        .update({
      'status': 'rejected',
      'processedAt': DateTime.now().toIso8601String(),
      'processedBy': processedBy,
      'notes': notes,
    });
  }

  Future<void> deleteHeadChangeRequest(String id) async {
    await FirebaseService.firestore
        .collection('head_change_requests')
        .doc(id)
        .delete();
  }

  Future<HeadChangeRequest?> getRequestById(String id) async {
    final doc = await FirebaseService.firestore
        .collection('head_change_requests')
        .doc(id)
        .get();
    if (!doc.exists) return null;
    return HeadChangeRequest.fromMap({...doc.data()!, 'id': doc.id});
  }
}
