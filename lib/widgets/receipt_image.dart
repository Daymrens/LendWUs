import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ReceiptImage extends StatelessWidget {
  final String? receiptUrl;
  final String? receiptPath;
  final double? height;
  final BoxFit fit;

  const ReceiptImage({
    super.key,
    this.receiptUrl,
    this.receiptPath,
    this.height,
    this.fit = BoxFit.cover,
  });

  bool get _isDataUrl => (receiptUrl ?? receiptPath ?? '').startsWith('data:image');
  bool get _isHttpUrl => (receiptUrl ?? '').startsWith('http');
  bool get _hasValue => (receiptUrl != null && receiptUrl!.isNotEmpty) || (receiptPath != null && receiptPath!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_hasValue) return const SizedBox.shrink();

    final source = receiptUrl ?? receiptPath!;

    if (_isDataUrl) {
      final base64Str = source.split(',').last;
      Uint8List bytes;
      try {
        bytes = base64Decode(base64Str);
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey));
      }
      return Image.memory(
        bytes,
        fit: fit,
        height: height,
        width: double.infinity,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
      );
    }

    if (_isHttpUrl) {
      return Image.network(
        source,
        fit: fit,
        height: height,
        width: double.infinity,
        loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
      );
    }

    return const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey));
  }
}
