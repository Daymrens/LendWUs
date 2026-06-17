import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/member_id_generator.dart';

class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  static const _seedFlagDoc = 'meta/seeded';
  static const _memberIdBackfillFlagDoc = 'meta/member_ids_backfilled';
  static const _appSettingsCollection = 'app_settings';

  static Future<void> seedDefaults() async {
    try {
      await firestore.runTransaction((tx) async {
        final flag = await tx.get(firestore.doc(_seedFlagDoc));
        if (flag.exists) return;

        final settingsRef = firestore.doc('$_appSettingsCollection/fund_settings');
        final qrRef = firestore.doc('$_appSettingsCollection/payment_qr');

        final existing = await tx.get(settingsRef);
        if (!existing.exists) {
          tx.set(settingsRef, {
            'minPaymentPerHead': 0.0,
            'maxPaymentPerHead': 1000.0,
            'loanInterestPercent': 10.0,
            'currencySymbol': '\u20B1',
            'currencyCode': 'PHP',
            'cutoffDay1': 13,
            'cutoffDay2': 28,
            'adminEmails': ['daymrens@gmail.com'],
            'treasurerEmails': [],
          });
        }

        final qrExisting = await tx.get(qrRef);
        if (!qrExisting.exists) {
          tx.set(qrRef, {
            'value': 'GCash: 09123456789\nName: Juan Dela Cruz',
          });
        }

        tx.set(firestore.doc(_seedFlagDoc), {
          'seededAt': FieldValue.serverTimestamp(),
        });
      });

      await backfillMemberIdsOnce();
    } catch (e) {
      debugPrint('seedDefaults error: $e');
    }
  }

  static Future<String?> uploadReceiptImage(File file, String memberId) async {
    try {
      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64';
    } catch (e) {
      debugPrint('uploadReceiptImage error: $e');
      return null;
    }
  }

  static Future<void> backfillMemberIdsOnce() async {
    try {
      final flagRef = firestore.doc(_memberIdBackfillFlagDoc);
      final flag = await flagRef.get();
      if (flag.exists) return;
      final count = await MemberIdGenerator.backfillMissingMemberIds(firestore);
      if (count > 0) {
        debugPrint('Backfilled $count member(s) with MemberID');
      }
      await flagRef.set({'at': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('backfillMemberIdsOnce error: $e');
    }
  }
}
