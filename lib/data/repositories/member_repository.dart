import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member.dart';
import 'activity_log_repository.dart';
import 'loan_repository.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/utils/member_id_generator.dart';

class MemberRepository {
  final LoanRepository _loanRepo;
  final ActivityLogRepository _activityLog;
  static const int _defaultPageSize = 100;

  MemberRepository({LoanRepository? loanRepo, ActivityLogRepository? activityLog})
      : _loanRepo = loanRepo ?? LoanRepository(),
        _activityLog = activityLog ?? ActivityLogRepository();

  Future<List<Member>> getAllMembers({int? limit, DocumentSnapshot? startAfter}) async {
    Query<Map<String, dynamic>> query = FirebaseService.firestore.collection('members');
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    query = query.limit(limit ?? _defaultPageSize);
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Member.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<Member?> getMemberById(String id) async {
    final doc = await FirebaseService.firestore.collection('members').doc(id).get();
    if (!doc.exists) return null;
    return Member.fromMap({...doc.data()!, 'id': doc.id});
  }

  Future<String> addMember(Member member) async {
    final firestore = FirebaseService.firestore;
    if (member.memberId == null || member.memberId!.isEmpty) {
      member.memberId = await MemberIdGenerator.generateNextMemberId(firestore);
    }
    final docRef = await firestore.collection('members').add(member.toMap());
    return docRef.id;
  }

  Future<List<String>> addMembersSequential(List<Member> members) async {
    final firestore = FirebaseService.firestore;
    final ids = await MemberIdGenerator.generateNextMemberIds(firestore, members.length);
    for (var i = 0; i < members.length; i++) {
      members[i].memberId = ids[i];
    }
    final created = <String>[];
    for (final m in members) {
      final ref = await firestore.collection('members').add(m.toMap());
      created.add(ref.id);
    }
    return created;
  }

  Future<void> updateMember(Member member) async {
    await FirebaseService.firestore
        .collection('members')
        .doc(member.id!)
        .update(member.toMap());
  }

  Future<void> updateMemberLinkedEmail(String memberId, String? email) async {
    await FirebaseService.firestore
        .collection('members')
        .doc(memberId)
        .update({'linkedEmail': email});
  }

  Future<void> updateMemberBalance(String memberId, double balance) async {
    await FirebaseService.firestore
        .collection('members')
        .doc(memberId)
        .update({'balance': balance});
  }

  Future<void> deleteMember(String id) async {
    if (await _loanRepo.hasActiveLoan(id)) {
      throw Exception('Cannot remove member with outstanding loan');
    }

    final firestore = FirebaseService.firestore;

    final memberSnap = await firestore.collection('members').doc(id).get();
    final memberData = memberSnap.data();
    final memberName = memberData?['name'] as String? ?? 'Unknown';
    final memberIdField = memberData?['memberId'] as String?;

    final pendingPayments = await firestore
        .collection('payment_requests')
        .where('memberId', isEqualTo: id)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (pendingPayments.docs.isNotEmpty) {
      throw Exception('Cannot remove member with pending payment requests');
    }

    final pendingLoans = await firestore
        .collection('loan_requests')
        .where('memberId', isEqualTo: id)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (pendingLoans.docs.isNotEmpty) {
      throw Exception('Cannot remove member with pending loan requests');
    }

    await firestore.collection('members').doc(id).delete();

    final user = FirebaseService.auth.currentUser;
    _activityLog.logActivity(
      action: 'member_deleted',
      entityType: 'member',
      entityId: id,
      performedBy: user?.uid,
      performedByName: user?.displayName,
      details: {
        'memberName': memberName,
        'memberId': memberIdField,
      },
    );
  }

  Stream<List<Member>> watchAllMembers() {
    return FirebaseService.firestore.collection('members').snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => Member.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<Member?> findMemberByLinkedEmail(String email) async {
    final snapshot = await FirebaseService.firestore
        .collection('members')
        .where('linkedEmail', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Member.fromMap({...snapshot.docs.first.data(), 'id': snapshot.docs.first.id});
  }
}
