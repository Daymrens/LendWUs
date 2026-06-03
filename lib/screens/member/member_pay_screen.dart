import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import '../../data/models/payment_request.dart';
import '../../data/repositories/payment_request_repository.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/currency_formatter.dart';

class MemberPayScreen extends ConsumerStatefulWidget {
  const MemberPayScreen({super.key});

  @override
  ConsumerState<MemberPayScreen> createState() => _MemberPayScreenState();
}

class _MemberPayScreenState extends ConsumerState<MemberPayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  File? _receiptImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    
    if (pickedFile != null) {
      setState(() {
        _receiptImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload receipt image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentUser = ref.read(currentUserProvider).state;
    final paymentRequest = PaymentRequest(
      memberId: currentUser!.memberId!,
      amount: double.parse(_amountController.text),
      receiptPath: _receiptImage!.path,
      status: PaymentStatus.pending,
      requestDate: DateTime.now(),
      type: PaymentType.contribution,
    );

    final repo = PaymentRequestRepository();
    await repo.createPaymentRequest(paymentRequest);

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment submitted! Waiting for admin approval'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // QR code data (in real app, this would come from settings)
    const qrData = 'GCash: 09123456789\nName: Juan Dela Cruz';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Contribution'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Scan QR Code to Pay',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'GCash: 09123456789\nName: Juan Dela Cruz',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₱ ',
                  border: const OutlineInputBorder(),
                  helperText: 'Enter the amount you paid',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_receiptImage != null) ...[
                Text(
                  'Receipt Image:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _receiptImage!,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt),
                label: Text(_receiptImage == null ? 'Take Receipt Photo' : 'Retake Photo'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
