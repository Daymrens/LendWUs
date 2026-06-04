import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  static Future<void> seedDefaults() async {
    try {
      final userSnapshot = await firestore.collection('users').limit(1).get();
      if (userSnapshot.docs.isNotEmpty) return;
    } catch (_) {
      return;
    }

    try {
      final adminCred = await auth.createUserWithEmailAndPassword(
        email: 'admin@sinkingfund.app',
        password: 'admin123',
      );

      await firestore.collection('users').doc(adminCred.user!.uid).set({
        'username': 'admin',
        'email': 'admin@sinkingfund.app',
        'role': 'admin',
        'memberId': null,
        'createdAt': DateTime.now().toIso8601String(),
      });

      final memberDoc = await firestore.collection('members').add({
        'name': 'Test Member',
        'headsCount': 1,
        'amountPerHead': 150.0,
        'totalRequired': 150.0,
        'joinedAt': DateTime.now().toIso8601String(),
        'isActive': true,
      });

      final memberCred = await auth.createUserWithEmailAndPassword(
        email: 'member@sinkingfund.app',
        password: 'member123',
      );

      await firestore.collection('users').doc(memberCred.user!.uid).set({
        'username': 'member',
        'email': 'member@sinkingfund.app',
        'role': 'member',
        'memberId': memberDoc.id,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await firestore.collection('app_settings').doc('payment_qr').set({
        'value': 'GCash: 09123456789\nName: Juan Dela Cruz',
      });

      await firestore.collection('app_settings').doc('fund_settings').set({
        'minPaymentPerHead': 0.0,
        'maxPaymentPerHead': 1000.0,
        'currencySymbol': '\u20B1',
        'currencyCode': 'PHP',
      });
    } catch (e) {
      // Accounts may already exist in Auth
    }
  }
}
