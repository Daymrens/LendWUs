import '../models/member.dart';
import '../../core/firebase/firebase_service.dart';

class MemberRepository {
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
    final docRef = await FirebaseService.firestore.collection('members').add(member.toMap());
    return docRef.id;
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
    await FirebaseService.firestore.collection('members').doc(id).delete();
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
