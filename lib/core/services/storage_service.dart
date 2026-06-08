import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String> uploadImage({
    required String folder,
    required String fileName,
    required List<int> bytes,
  }) async {
    final path = '$folder/$fileName';
    final ref = _storage.ref().child(path);
    await ref.putData(Uint8List.fromList(bytes));
    return await ref.getDownloadURL();
  }

  static Future<String> uploadReceipt({
    required String memberId,
    required List<int> bytes,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadImage(
      folder: 'receipts/$memberId',
      fileName: fileName,
      bytes: bytes,
    );
  }
}
