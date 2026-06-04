import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gap/gap.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/member.dart';
import '../../data/repositories/payment_request_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../core/utils/currency_formatter.dart';

String _cutoffStatus(int cutoffDay1, int cutoffDay2) {
  final now = DateTime.now();
  final today = now.day;

  // Find nearest past and upcoming cutoffs
  final cutoffs = [cutoffDay1, cutoffDay2]..sort();
  int? nextCutoff;
  int? prevCutoff;
  for (final c in cutoffs) {
    if (c >= today) {
      nextCutoff = c;
      break;
    }
    prevCutoff = c;
  }
  if (nextCutoff == null) {
    // All cutoffs passed this month; next is first cutoff next month
    nextCutoff = cutoffs.first + DateTime.now().add(const Duration(days: 31)).day;
    prevCutoff = cutoffs.last;
  }

  final daysUntilNext = nextCutoff - today;
  final daysSincePrev = today - (prevCutoff ?? 0);

  if (daysUntilNext <= 0) return 'Due today';
  if (daysUntilNext <= 3) return '$daysUntilNext day${daysUntilNext == 1 ? "" : "s"} until cutoff';
  if (daysSincePrev > 0 && daysSincePrev <= 3) return 'Overdue by $daysSincePrev day${daysSincePrev == 1 ? "" : "s"}';
  return 'Next cutoff in $daysUntilNext days';
}

Color _cutoffColor(int cutoffDay1, int cutoffDay2) {
  final now = DateTime.now();
  final today = now.day;
  final cutoffs = [cutoffDay1, cutoffDay2]..sort();
  int? nextCutoff;
  int? prevCutoff;
  for (final c in cutoffs) {
    if (c >= today) {
      nextCutoff = c;
      break;
    }
    prevCutoff = c;
  }
  nextCutoff ??= cutoffs.first;
  final daysUntilNext = nextCutoff - today;
  final daysSincePrev = today - (prevCutoff ?? 0);

  if (daysUntilNext <= 0) return AppColors.warning;
  if (daysUntilNext <= 3) return Colors.orange;
  if (daysSincePrev > 0 && daysSincePrev <= 7) return AppColors.error;
  return AppColors.success;
}

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
  bool _showQR = true;
  Member? _member;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMember());
  }

  Future<void> _loadMember() async {
    final user = ref.read(currentUserProvider).state;
    if (user?.memberId == null) return;
    final repo = MemberRepository();
    final m = await repo.getMemberById(user!.memberId!);
    if (mounted) setState(() => _member = m);
  }

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

  String? _amountValidator(String? value, double minAmount, double maxAmount) {
    if (value == null || value.isEmpty) return 'Please enter amount';
    final parsed = double.tryParse(value);
    if (parsed == null) return 'Please enter valid amount';
    if (parsed <= 0) return 'Amount must be greater than 0';
    if (parsed < minAmount) return 'Minimum is ${CurrencyFormatter.format(minAmount)}';
    if (parsed > maxAmount) return 'Maximum is ${CurrencyFormatter.format(maxAmount)}';
    return null;
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

      final request = PaymentRequest(
        memberId: user!.memberId!,
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
    final user = ref.watch(currentUserProvider).state;
    final memberId = user?.memberId;
    final settings = ref.watch(settingsProvider).asData?.value;
    final minAmount = settings?.minPaymentPerHead ?? 150.0;
    final maxAmount = settings?.maxPaymentPerHead ?? 1000.0;

    final contributionsAsync = ref.watch(contributionsStreamProvider);
    final contribs = [...?contributionsAsync.asData?.value];
    final now = DateTime.now();
    final thisMonthContribs = contribs.where((c) =>
      c.memberId == memberId &&
      c.date.month == now.month &&
      c.date.year == now.year
    ).toList();
    final thisMonthTotal = thisMonthContribs.fold<double>(0.0, (s, c) => s + c.amount);
    final effectiveRequired = minAmount.clamp(0.0, double.infinity);
    final totalRequired = _member?.totalRequired ?? effectiveRequired;
    final progress = totalRequired > 0 ? (thisMonthTotal / totalRequired).clamp(0.0, 1.0) : 0.0;
    final met = thisMonthTotal >= totalRequired;
    final balance = _member?.balance ?? 0.0;
    final cutoffDay1 = settings?.cutoffDay1 ?? 13;
    final cutoffDay2 = settings?.cutoffDay2 ?? 28;

    // Dynamic quick amounts based on totalRequired
    final quickAmounts = [
      totalRequired * 0.25,
      totalRequired * 0.5,
      totalRequired * 0.75,
      totalRequired,
    ].map((a) => (a * 100).round() / 100).toList();

    final memberName = user?.username ?? 'Member';

    // Quick amounts cap at maxAmount from settings
    final cappedQuickAmounts = quickAmounts.map((a) => a > maxAmount ? maxAmount : a).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
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
                    const SizedBox(height: 16),

                    // Member info + progress
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary.withAlpha(30),
                          child: Text(
                            memberName[0].toUpperCase(),
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        const Gap(12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Text('Member', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const Gap(20),

                    // Monthly progress card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('This Month ($totalRequired/head)', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                              Text(
                                '${CurrencyFormatter.format(thisMonthTotal)} / ${CurrencyFormatter.format(totalRequired)}',
                                style: TextStyle(
                                  color: met ? AppColors.primary : AppColors.warning,
                                  fontWeight: FontWeight.bold, fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: met ? 1.0 : progress,
                              backgroundColor: AppColors.surfaceAlt,
                              color: met ? AppColors.primary : AppColors.warning,
                              minHeight: 8,
                            ),
                          ),
                          const Gap(6),
                          Text(
                            met ? 'Requirement met for this month' : '${CurrencyFormatter.format(totalRequired - thisMonthTotal)} remaining this month',
                            style: TextStyle(
                              color: met ? AppColors.primary : AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          if (balance > 0) ...[
                            const Gap(6),
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet, size: 14, color: AppColors.success),
                                const Gap(4),
                                Text(
                                  'Credit balance: ${CurrencyFormatter.format(balance)}',
                                  style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                          const Gap(8),
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 14, color: _cutoffColor(cutoffDay1, cutoffDay2)),
                              const Gap(4),
                              Text(
                                _cutoffStatus(cutoffDay1, cutoffDay2),
                                style: TextStyle(
                                  color: _cutoffColor(cutoffDay1, cutoffDay2),
                                  fontSize: 11, fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Gap(20),

                    // Quick amounts
                    const Text('Quick Amount', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                    const Gap(10),
                    Row(
                      children: cappedQuickAmounts.map((amount) {
                        final selected = _amountController.text == amount.toStringAsFixed(2);
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: amount == cappedQuickAmounts.first ? 0 : 6,
                              right: amount == cappedQuickAmounts.last ? 0 : 6,
                            ),
                            child: GestureDetector(
                              onTap: () => setState(() => _amountController.text = amount.toStringAsFixed(2)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.primary.withAlpha(20) : AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                  border: selected ? Border.all(color: AppColors.primary) : null,
                                ),
                                child: Text(
                                  CurrencyFormatter.format(amount),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected ? AppColors.primary : AppColors.textPrimary,
                                    fontWeight: FontWeight.w600, fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Gap(20),

                    // Amount field
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount (${CurrencyFormatter.currencySymbol})',
                        prefixText: '${CurrencyFormatter.currencySymbol} ',
                        helperText: 'Min: ${CurrencyFormatter.format(minAmount)}  •  Max: ${CurrencyFormatter.format(maxAmount)}',
                        helperStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => _amountValidator(v, minAmount, maxAmount),
                    ),
                    const Gap(24),

                    // QR code (collapsible)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _showQR = !_showQR),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  const Icon(Icons.qr_code, size: 20, color: AppColors.textMuted),
                                  const Gap(10),
                                  const Text('Scan to pay via GCash/PayMaya',
                                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
                                  const Spacer(),
                                  Icon(_showQR ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted),
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
                                    ),
                                    child: QrImageView(
                                      data: 'SINKING_FUND_PAYMENT',
                                      version: QrVersions.auto,
                                      size: 180,
                                    ),
                                  ),
                                  const Gap(8),
                                  const Text('Scan with GCash, PayMaya, or any PH bank app',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Gap(24),

                    // Receipt Upload
                    const Text('Upload Receipt', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                    const Gap(10),

                    if (_receiptImage != null)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Image.file(
                                _receiptImage!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.image, size: 16, color: AppColors.textMuted),
                                  const Gap(8),
                                  Expanded(
                                    child: Text(
                                      _receiptImage!.path.split('/').last,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${(_receiptImage!.lengthSync() / 1024).toStringAsFixed(0)} KB',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
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
        },
      ),
    );
  }
}
