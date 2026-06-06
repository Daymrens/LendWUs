import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gap/gap.dart';
import 'dart:io';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../core/firebase/firebase_service.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/member.dart';
import '../../data/repositories/payment_request_repository.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../modals/pending_approval_dialog.dart';

class MemberPayScreen extends ConsumerStatefulWidget {
  final String? loanId;
  final PaymentType paymentType;

  const MemberPayScreen({
    super.key, 
    this.loanId, 
    this.paymentType = PaymentType.contribution,
  });

  @override
  ConsumerState<MemberPayScreen> createState() => _MemberPayScreenState();
}

class _MemberPayScreenState extends ConsumerState<MemberPayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  File? _receiptImage;
  bool _isSubmitting = false;
  double? _remainingBalance;
  bool _isLoadingBalance = false;
  bool _showQR = true;
  Member? _member;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMember());
    if (widget.loanId != null) {
      _fetchRemainingBalance();
    }
  }

  Future<void> _loadMember() async {
    final user = ref.read(currentUserProvider).state;
    if (user?.memberId == null) return;
    final repo = MemberRepository();
    final m = await repo.getMemberById(user!.memberId!);
    if (mounted) setState(() => _member = m);
  }

  Future<void> _fetchRemainingBalance() async {
    setState(() => _isLoadingBalance = true);
    final repo = LoanRepository();
    final balance = await repo.getRemainingBalance(widget.loanId!);
    if (mounted) {
      setState(() {
        _remainingBalance = balance;
        _isLoadingBalance = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _receiptImage = File(pickedFile.path));
    }
  }

  Future<void> _takePhoto() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _receiptImage = File(pickedFile.path));
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload receipt image'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentUser = ref.read(currentUserProvider).state;

    String? receiptUrl;
    if (_receiptImage != null) {
      receiptUrl = await FirebaseService.uploadReceiptImage(
        File(_receiptImage!.path), currentUser!.memberId!,
      );
    }

    final paymentRequest = PaymentRequest(
      memberId: currentUser!.memberId!,
      loanId: widget.loanId,
      amount: double.parse(_amountController.text),
      receiptPath: receiptUrl ?? _receiptImage?.path,
      receiptUrl: receiptUrl,
      status: PaymentStatus.pending,
      requestDate: DateTime.now(),
      type: widget.paymentType,
    );

    final repo = PaymentRequestRepository();
    await repo.createPaymentRequest(paymentRequest);

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PendingApprovalDialog(
        title: 'Payment Submitted',
        message: 'Your payment request has been received. Please wait for admin confirmation.',
      ),
    ).then((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    const qrData = 'GCash: 09123456789\nName: Juan Dela Cruz';
    final colorScheme = Theme.of(context).colorScheme;
    final isLoan = widget.paymentType == PaymentType.loan;
    final settings = ref.watch(settingsProvider).asData?.value;
    final perHead = settings?.minPaymentPerHead ?? 500.0;
    final heads = _member?.headsCount ?? 1;
    final totalRequired = (_member?.totalRequired ?? 0.0) > 0 ? _member!.totalRequired : heads * perHead;

    return Scaffold(
      appBar: AppBar(
        title: Text(isLoan ? 'Repay Loan' : 'Pay Contribution'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Member info card
              if (_member != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withAlpha(25),
                        child: Text(
                          (_member!.name ?? 'M')[0].toUpperCase(),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_member!.name ?? 'Member',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (!isLoan) ...[
                              const Gap(4),
                              Row(
                                children: [
                                  _labelChip('$heads head${heads > 1 ? 's' : ''}', AppColors.primary),
                                  const Gap(8),
                                  _labelChip('Req: ${CurrencyFormatter.format(totalRequired)}', AppColors.secondary),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Gap(16),

              // Loan balance card
              if (isLoan && _remainingBalance != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.warning.withAlpha(30), AppColors.warning.withAlpha(10)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.warning.withAlpha(60)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance, color: AppColors.warning, size: 20),
                          const Gap(8),
                          const Text('Remaining Balance',
                            style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                      const Gap(12),
                      Text(CurrencyFormatter.format(_remainingBalance!),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.warning, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else if (isLoan && _isLoadingBalance)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )),
              if (isLoan) const Gap(16),

              // QR Code section
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showQR = !_showQR),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.qr_code, size: 20, color: AppColors.primary),
                            ),
                            const Gap(12),
                            const Text('Scan QR Code to Pay',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const Spacer(),
                            Icon(_showQR ? Icons.expand_less : Icons.expand_more, color: colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                    if (_showQR) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const Gap(12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'GCash: 09123456789  •  Name: Juan Dela Cruz',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(24),

              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (${CurrencyFormatter.currencySymbol})',
                  prefixText: '${CurrencyFormatter.currencySymbol} ',
                  border: const OutlineInputBorder(),
                  helperText: isLoan ? 'Enter amount to repay' : 'Enter the amount you paid',
                  helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter amount';
                  final amount = double.tryParse(value);
                  if (amount == null) return 'Please enter valid amount';
                  if (amount <= 0) return 'Amount must be greater than zero';
                  return null;
                },
              ),
              const Gap(24),

              // Receipt section
              const Text('Upload Receipt',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
              const Gap(10),

              if (_receiptImage != null)
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.file(_receiptImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.image, size: 16, color: AppColors.textMuted),
                            const Gap(8),
                            Expanded(
                              child: Text(_receiptImage!.path.split('\\').last,
                                style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            ),
                            Text('${(_receiptImage!.lengthSync() / 1024).toStringAsFixed(0)} KB',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            const Gap(8),
                            GestureDetector(
                              onTap: () => setState(() => _receiptImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.close, size: 14, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Camera'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit for Approval', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labelChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
