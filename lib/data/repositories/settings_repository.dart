import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firebase_service.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final FirebaseFirestore _firestore = FirebaseService.firestore;

  Future<AppSettings> getSettings() async {
    final doc = await _firestore.collection('app_settings').doc('fund_settings').get();
    if (!doc.exists) {
      // Default settings
      final defaultSettings = AppSettings(
        minPaymentPerHead: 0.0,
        maxPaymentPerHead: 1000.0,
        loanInterestPercent: 10.0,
        currencySymbol: '\u20B1',
        currencyCode: 'PHP',
        cutoffDay1: 13,
        cutoffDay2: 28,
        adminEmails: ['act.drapor@gmail.com', 'daymrens@gmail.com'],
      );
      await saveSettings(defaultSettings);
      return defaultSettings;
    }
    return AppSettings.fromMap(doc.data()!);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _firestore.collection('app_settings').doc('fund_settings').set(settings.toMap());
  }

  Stream<AppSettings> watchSettings() {
    return _firestore.collection('app_settings').doc('fund_settings').snapshots().map((doc) {
      if (!doc.exists) {
        return AppSettings(
          minPaymentPerHead: 0.0,
          maxPaymentPerHead: 1000.0,
          loanInterestPercent: 10.0,
          currencySymbol: '\u20B1',
          currencyCode: 'PHP',
          cutoffDay1: 13,
          cutoffDay2: 28,
          adminEmails: ['act.drapor@gmail.com', 'daymrens@gmail.com'],
        );
      }
      return AppSettings.fromMap(doc.data()!);
    });
  }
}
