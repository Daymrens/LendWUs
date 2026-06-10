import 'dart:convert';

class StorageService {
  static Future<String> uploadReceipt({
    required String memberId,
    required List<int> bytes,
  }) async {
    // Spark plan has no Cloud Storage - store as base64 data URL in Firestore
    final base64 = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64';
  }
}
