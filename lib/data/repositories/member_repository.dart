import 'package:cloud_firestore/cloud_firestore.dart';
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
}
