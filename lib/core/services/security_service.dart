import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/firebase/firebase_service.dart';
import 'biometric_service_stub.dart' as bio;

class SecurityService {
  static String get _userId {
    final user = FirebaseService.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.uid;
  }

  static Future<bool> isBiometricAvailable() => bio.isAvailable();
  static Future<String?> getBiometricStatus() => bio.getError();

  static Future<bool> authenticateWithBiometrics({void Function(String)? onError}) async {
    try {
      return await bio.authenticate();
    } catch (e) {
      debugPrint('SecurityService biometric error: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  static Future<bool> authenticateWithPasscode() async {
    try {
      return await bio.authenticateWithPasscode();
    } catch (_) {
      return false;
    }
  }

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const _bioEmailKey = 'biometric_login_email';
  static const _bioPasswordKey = 'biometric_login_password';

  static Future<void> saveBiometricCredentials(String email, String password) async {
    await _secureStorage.write(key: _bioEmailKey, value: email);
    await _secureStorage.write(key: _bioPasswordKey, value: password);
  }

  static Future<String?> getBiometricEmail() async {
    return await _secureStorage.read(key: _bioEmailKey);
  }

  static Future<String?> getBiometricPassword() async {
    return await _secureStorage.read(key: _bioPasswordKey);
  }

  static Future<bool> hasBiometricCredentials() async {
    final email = await _secureStorage.read(key: _bioEmailKey);
    return email != null && email.isNotEmpty;
  }

  static Future<void> clearBiometricCredentials() async {
    await _secureStorage.delete(key: _bioEmailKey);
    await _secureStorage.delete(key: _bioPasswordKey);
  }

  static Future<String> generateBackupCode() async {
    final random = Random.secure();
    final code = List.generate(8, (_) => random.nextInt(10).toString()).join();
    final uid = _userId;
    await FirebaseService.firestore.collection('user_settings').doc(uid).set({
      'backup_code_hash': _hashCode(code),
      'backup_code_updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    return code;
  }

  static Future<bool> verifyBackupCode(String code) async {
    try {
      final uid = _userId;
      final doc = await FirebaseService.firestore.collection('user_settings').doc(uid).get();
      final storedHash = doc.data()?['backup_code_hash'] as String?;
      if (storedHash == null) return false;
      return storedHash == _hashCode(code);
    } catch (_) {
      return false;
    }
  }

  static String _hashCode(String code) {
    var hash = 0;
    for (var i = 0; i < code.length; i++) {
      hash = 31 * hash + code.codeUnitAt(i);
    }
    return hash.toRadixString(16);
  }

  static Future<void> enableBiometricAuth() async {
    await bio.setEnabled(true);
    final uid = _userId;
    await FirebaseService.firestore.collection('user_settings').doc(uid).set({
      'biometric_enabled': true,
      'biometric_updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    final email = FirebaseService.auth.currentUser?.email;
    if (email != null) {
      await saveBiometricCredentials(email, '');
    }
  }

  static Future<void> disableBiometricAuth() async {
    await bio.setEnabled(false);
    final uid = _userId;
    await FirebaseService.firestore.collection('user_settings').doc(uid).set({
      'biometric_enabled': false,
      'biometric_updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await clearBiometricCredentials();
  }

  static Future<bool> isBiometricEnabled() async {
    try {
      final uid = _userId;
      final doc = await FirebaseService.firestore.collection('user_settings').doc(uid).get();
      return doc.data()?['biometric_enabled'] == true;
    } catch (_) {
      return false;
    }
  }
}

class TwoFactorAuthService {
  static String get _userId {
    final user = FirebaseService.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.uid;
  }

  static Future<void> enableTwoFactorAuth() async {
    final uid = _userId;
    await FirebaseService.firestore.collection('user_settings').doc(uid).set({
      'two_factor_enabled': true,
      'two_factor_updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  static Future<void> disableTwoFactorAuth() async {
    final uid = _userId;
    await FirebaseService.firestore.collection('user_settings').doc(uid).set({
      'two_factor_enabled': false,
      'two_factor_updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  static Future<bool> isTwoFactorEnabled() async {
    try {
      final uid = _userId;
      final doc = await FirebaseService.firestore.collection('user_settings').doc(uid).get();
      return doc.data()?['two_factor_enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> generateOTP() async {
    final random = Random.secure();
    final otp = List.generate(6, (_) => random.nextInt(10).toString()).join();
    final uid = _userId;
    await FirebaseService.firestore.collection('otp_codes').doc(uid).set({
      'otp': _hashOTP(otp),
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
    });
    return otp;
  }

  static Future<bool> verifyOTP(String otp) async {
    try {
      final uid = _userId;
      final doc = await FirebaseService.firestore.collection('otp_codes').doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      final expiresAt = DateTime.parse(data['expires_at'] as String);
      if (DateTime.now().isAfter(expiresAt)) return false;
      return data['otp'] == _hashOTP(otp);
    } catch (_) {
      return false;
    }
  }

  static String _hashOTP(String otp) {
    var hash = 0;
    for (var i = 0; i < otp.length; i++) {
      hash = 31 * hash + otp.codeUnitAt(i);
    }
    return hash.toRadixString(16);
  }

  static Future<void> sendOTPToEmail(String userEmail) async {
    final otp = await generateOTP();
    await FirebaseService.firestore.collection('email_logs').add({
      'to': userEmail,
      'subject': 'Your OTP Code',
      'body': 'Your OTP code is: $otp\nThis code expires in 5 minutes.',
      'sent_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }
}

class DataBackupService {
  static String get _userId {
    final user = FirebaseService.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.uid;
  }

  static Future<void> backupData() async {
    try {
      final collections = ['members', 'contributions', 'loans', 'repayments', 'returns', 'notifications'];
      final batch = FirebaseService.firestore.batch();
      int batchCount = 0;

      for (final collection in collections) {
        final snapshot = await FirebaseService.firestore.collection(collection).get();
        if (snapshot.docs.isEmpty) continue;

        final backupId = DateTime.now().millisecondsSinceEpoch.toString();
        final allData = snapshot.docs.map((doc) => ({
          'id': doc.id,
          ...doc.data(),
        })).toList();

        const chunkSize = 50;
        for (var i = 0; i < allData.length; i += chunkSize) {
          final chunk = allData.sublist(i, (i + chunkSize).clamp(0, allData.length));
          final chunkRef = FirebaseService.firestore
              .collection('backups')
              .doc('${collection}_${backupId}_${i ~/ chunkSize}');
          batch.set(chunkRef, {
            'collection': collection,
            'chunk_index': i ~/ chunkSize,
            'total_chunks': (allData.length / chunkSize).ceil(),
            'count': chunk.length,
            'data': chunk,
            'backup_date': DateTime.now().toIso8601String(),
            'created_by': _userId,
          });
          batchCount++;

          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      print('Backup error: $e');
      rethrow;
    }
  }

  static Future<void> scheduleAutoBackup() async {
    await FirebaseService.firestore.collection('settings').doc('backup_config').set({
      'auto_backup_enabled': true,
      'backup_frequency': 'daily',
      'last_backup': DateTime.now().toIso8601String(),
      'next_backup': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
    }, SetOptions(merge: true));
  }

  static Future<void> cleanupOldBackups() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final oldBackups = await FirebaseService.firestore
        .collection('backups')
        .where('backup_date', isLessThan: thirtyDaysAgo.toIso8601String())
        .get();
    final batch = FirebaseService.firestore.batch();
    for (final doc in oldBackups.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
