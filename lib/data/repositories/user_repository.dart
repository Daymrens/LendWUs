import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../../core/firebase/firebase_service.dart';

class UserRepository {
  Future<User?> login(String email, String password) async {
    try {
      final credential = await FirebaseService.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return await getUserById(credential.user!.uid);
    } on FirebaseAuthException {
      return null;
    }
  }

  Future<int> createUser(User user, String password) async {
    try {
      final credential = await FirebaseService.auth.createUserWithEmailAndPassword(
        email: user.email,
        password: password,
      );
      final uid = credential.user!.uid;
      await FirebaseService.firestore.collection('users').doc(uid).set({
        ...user.toMap(),
        'id': uid,
      });
      return 1;
    } catch (e) {
      return 0;
    }
  }

  Future<void> createUserDoc(User user) async {
    await FirebaseService.firestore.collection('users').doc(user.id).set({
      ...user.toMap(),
    });
  }

  Future<User?> getUserById(String id) async {
    final doc = await FirebaseService.firestore.collection('users').doc(id).get();
    if (!doc.exists) return null;
    return User.fromMap({...doc.data()!, 'id': doc.id});
  }

  Future<List<User>> getAllUsers() async {
    final snapshot = await FirebaseService.firestore.collection('users').get();
    return snapshot.docs.map((doc) => User.fromMap({...doc.data(), 'id': doc.id})).toList();
  }

  Future<bool> usernameExists(String username) async {
    final snapshot = await FirebaseService.firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<List<User>> getUsersWithoutMemberId() async {
    final allUsers = await getAllUsers();
    return allUsers.where((u) => u.memberId == null).toList();
  }

  Future<void> updateUserMemberId(String userId, String memberId) async {
    await FirebaseService.firestore
        .collection('users')
        .doc(userId)
        .set({'memberId': memberId}, SetOptions(merge: true));
  }

  Future<void> updateFcmToken(String userId, String? token) async {
    await FirebaseService.firestore
        .collection('users')
        .doc(userId)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<void> updateUserProfile(String userId, {String? name, String? photoUrl}) async {
    final data = <String, dynamic>{};
    if (name != null) data['username'] = name;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (data.isNotEmpty) {
      await FirebaseService.firestore
          .collection('users')
          .doc(userId)
          .set(data, SetOptions(merge: true));
    }
  }
}
