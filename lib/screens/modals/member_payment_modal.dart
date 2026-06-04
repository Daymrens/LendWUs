import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../data/models/payment_request.dart';
import '../../data/repositories/payment_request_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../core/utils/currency_formatter.dart';

class MemberPaymentModal extends ConsumerStatefulWidget {
  const MemberPaymentModal({super.key});

  @override
  ConsumerState<MemberPaymentModal> createState() => _MemberPaymentModalState();
}

class _MemberPaymentModalState extends ConsumerState<MemberPaymentModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '150.00');
  File? _receiptImage;
  bool _isSubmitting = false;
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    
    if (pickedFile != null) {
      setState(() => _receiptImage = File(pickedFile.path));
    }
  }

  Future<void> _takePhoto() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    
    if (pickedFile != null) {
      setState(() => _receiptImage = File(pickedFile.path));
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a receipt')),
      );
      return;
    }

    final user = ref.read(currentUserProvider).state;
    if (user?.memberId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = PaymentRequestRepository();
      final memberRepo = MemberRepository();
      final member = await memberRepo.getMemberById(user!.memberId!);

      final request = PaymentRequest(
        memberId: user.memberId!,
        amount: double.parse(_amountController.text),
        receiptPath: _receiptImage!.path,
        status: PaymentStatus.pending,
        requestDate: DateTime.now(),
        type: PaymentType.contribution,
      );

      await repo.createPaymentRequest(request);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment submitted! Waiting for admin approval'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pay Contribution',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // QR Code
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: 'SINKING_FUND_PAYMENT',
                      version: QrVersions.auto,
                      size: 200,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Scan to pay via GCash/PayMaya',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                
                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount (${CurrencyFormatter.currencySymbol})',
                    prefixText: '${CurrencyFormatter.currencySymbol} ',
                  ),
                  keyboardType: TextInputType.number,
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
                
                const SizedBox(height: 24),
                
                // Receipt Upload
                Text(
                  'Upload Receipt',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                if (_receiptImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _receiptImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => setState(() => _receiptImage = null),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitPayment,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit for Approval'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
