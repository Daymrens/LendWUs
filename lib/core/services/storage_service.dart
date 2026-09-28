import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

class ReceiptUploadResult {
  final String url;
  final String hash;
  final int compressedSizeBytes;

  ReceiptUploadResult({
    required this.url,
    required this.hash,
    required this.compressedSizeBytes,
  });
}

class StorageService {
  static const int _maxDimension = 1024;
  static const int _jpegQuality = 70;
  static const int _maxSizeBytes = 900 * 1024;

  static Future<ReceiptUploadResult> uploadReceipt({
    required String memberId,
    required List<int> bytes,
  }) async {
    final original = img.decodeImage(Uint8List.fromList(bytes));
    if (original == null) {
      throw Exception('Failed to decode receipt image');
    }

    final resized = (original.width > _maxDimension || original.height > _maxDimension)
        ? img.copyResize(original, width: _maxDimension)
        : original;

    final compressed = Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));

    if (compressed.length > _maxSizeBytes) {
      throw Exception(
        'Receipt image is too large (${(compressed.length / 1024).toStringAsFixed(1)}KB). '
        'Maximum allowed is 900KB after compression.',
      );
    }

    final hash = sha256.convert(compressed).toString();
    final base64Str = base64Encode(compressed);
    final url = 'data:image/jpeg;base64,$base64Str';

    return ReceiptUploadResult(
      url: url,
      hash: hash,
      compressedSizeBytes: compressed.length,
    );
  }
}
