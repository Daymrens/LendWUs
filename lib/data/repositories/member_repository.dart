import '../models/member.dart';
import 'loan_repository.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/utils/member_id_generator.dart';

class MemberRepository {
  final LoanRepository _loanRepo;

  MemberRepository({LoanRepository? loanRepo}) : _loanRepo = loanRepo ?? LoanRepository();

  Future<List<Member>> getAllMembers() async {
    final snapshot = await FirebaseService.firestore.collection('members').get();
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

  Future<void> deleteMember(String id) async {
    if (await _loanRepo.hasActiveLoan(id)) {
      throw Exception('Cannot remove member with outstanding loan');
    }

    final firestore = FirebaseService.firestore;

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
