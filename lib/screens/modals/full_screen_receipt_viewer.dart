import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class FullScreenReceiptViewer extends StatelessWidget {
  final String receiptUrl;

  const FullScreenReceiptViewer({super.key, required this.receiptUrl});

  @override
  Widget build(BuildContext context) {
    String debugText;
    Widget body;

    if (!receiptUrl.startsWith('data:image')) {
      debugText = 'NOT base64 — ${receiptUrl.length} chars, starts with: ${receiptUrl.substring(0, 30)}';
      body = Image.network(
        receiptUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, e, __) => Center(child: Text('Network err: $e', style: const TextStyle(color: Colors.red, fontSize: 20))),
      );
    } else {
      Uint8List? bytes;
      try {
        bytes = base64Decode(receiptUrl.split(',').last);
        debugText = 'Base64 OK: ${bytes.length} bytes';
      } catch (e) {
        debugText = 'Base64 FAIL: $e';
        bytes = null;
      }
      body = bytes != null
          ? Image.memory(bytes, fit: BoxFit.contain,
              errorBuilder: (_, e, __) => Center(child: Text('Image err: $e', style: const TextStyle(color: Colors.red, fontSize: 20))))
          : Center(child: Text('Decode failed', style: const TextStyle(color: Colors.red, fontSize: 20)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Receipt'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.amber[900],
            width: double.infinity,
            child: Text(debugText, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Expanded(child: Center(child: body)),
        ],
      ),
    );
  }
}
