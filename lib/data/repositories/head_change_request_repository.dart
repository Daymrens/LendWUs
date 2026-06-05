import '../models/head_change_request.dart';
import 'notification_repository.dart';
import '../../core/firebase/firebase_service.dart';

class HeadChangeRequestRepository {
  Future<String> createHeadChangeRequest(HeadChangeRequest request) async {
    final docRef = await FirebaseService.firestore
        .collection('head_change_requests')
        .add(request.toMap());

    final change = request.requestedHeads - request.currentHeads;
    final changeStr = change >= 0 ? '+$change' : '$change';
    NotificationRepository.notifyAdmins(
      'New Head Change Request',
      '${request.memberName} wants to change heads from ${request.currentHeads} to ${request.requestedHeads} ($changeStr)',
      type: 'head_change_request_created',
    );

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

  Future<bool> approveHeadChangeRequest(String requestId, {String? processedBy, String? notes}) async {
    final firestore = FirebaseService.firestore;
    final requestRef = firestore.collection('head_change_requests').doc(requestId);

    final result = await firestore.runTransaction<({String memberId, int currentHeads, int requestedHeads})?>((tx) async {
      final snap = await tx.get(requestRef);
      if (!snap.exists) return null;
      final data = snap.data()!;
      if (data['status'] != 'pending') return null;

      final memberId = data['memberId'] as String;
      final memberRef = firestore.collection('members').doc(memberId);
      final memberDoc = await tx.get(memberRef);
      if (!memberDoc.exists) return null;

      final memberData = memberDoc.data()!;
      final amountPerHead = (memberData['amountPerHead'] as num?)?.toDouble() ?? 0.0;
      final requestedHeads = (data['requestedHeads'] as num).toInt();

      tx.update(memberRef, {
        'headsCount': requestedHeads,
        'totalRequired': requestedHeads * amountPerHead,
      });
      tx.update(requestRef, {
        'status': 'approved',
        'processedAt': DateTime.now().toIso8601String(),
        'processedBy': processedBy,
        'notes': notes,
      });

      return (
        memberId: memberId,
        currentHeads: (data['currentHeads'] as num).toInt(),
        requestedHeads: requestedHeads,
      );
    });

    if (result == null) return false;

    NotificationRepository.notifyMember(
      result.memberId,
      'Head Change Approved',
      'Your request to change heads from ${result.currentHeads} to ${result.requestedHeads} has been approved',
      type: 'head_change_approved',
    );
    return true;
  }

  Future<bool> rejectHeadChangeRequest(String requestId, {String? processedBy, String? notes}) async {
    final firestore = FirebaseService.firestore;
    final requestRef = firestore.collection('head_change_requests').doc(requestId);

    final request = await firestore.runTransaction((tx) async {
      final snap = await tx.get(requestRef);
      if (!snap.exists) return null;
      final data = snap.data()!;
      if (data['status'] != 'pending') return null;
      tx.update(requestRef, {
        'status': 'rejected',
        'processedAt': DateTime.now().toIso8601String(),
        'processedBy': processedBy,
        'notes': notes,
      });
      return HeadChangeRequest.fromMap({...data, 'id': requestId});
    });

    if (request == null) return false;

    final reason = notes != null && notes.isNotEmpty ? ': $notes' : '';
    NotificationRepository.notifyMember(
      request.memberId,
      'Head Change Rejected',
      'Your request to change heads from ${request.currentHeads} to ${request.requestedHeads} has been rejected$reason',
      type: 'head_change_rejected',
    );
    return true;
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
