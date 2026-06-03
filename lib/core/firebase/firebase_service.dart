import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/user.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static FirebaseAuth get auth => _auth;
  static FirebaseFirestore get firestore => _firestore;

  static Future<void> seedDefaults() async {
    final userSnapshot = await _firestore.collection('users').limit(1).get();
    if (userSnapshot.docs.isNotEmpty) return;

    try {
      final adminCred = await _auth.createUserWithEmailAndPassword(
        email: 'admin@sinkingfund.app',
        password: 'admin123',
      );

      await _firestore.collection('users').doc(adminCred.user!.uid).set({
        'username': 'admin',
        'email': 'admin@sinkingfund.app',
        'role': 'admin',
        'memberId': null,
        'createdAt': DateTime.now().toIso8601String(),
      });

      final memberDoc = await _firestore.collection('members').add({
        'name': 'Test Member',
        'headsCount': 1,
        'amountPerHead': 150.0,
        'totalRequired': 150.0,
        'joinedAt': DateTime.now().toIso8601String(),
        'isActive': true,
      });

      final memberCred = await _auth.createUserWithEmailAndPassword(
        email: 'member@sinkingfund.app',
        password: 'member123',
      );

      await _firestore.collection('users').doc(memberCred.user!.uid).set({
        'username': 'member',
        'email': 'member@sinkingfund.app',
        'role': 'member',
        'memberId': memberDoc.id,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await _firestore.collection('app_settings').doc('payment_qr').set({
        'value': 'GCash: 09123456789\nName: Juan Dela Cruz',
      });
    } catch (e) {
      // Accounts may already exist in Auth
    }
  }
}
