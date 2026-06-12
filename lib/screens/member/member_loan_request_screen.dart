import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/loan_request.dart';
import '../../data/models/member.dart';
import '../../data/repositories/loan_request_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../modals/pending_approval_dialog.dart';

class MemberLoanRequestScreen extends ConsumerStatefulWidget {
  const MemberLoanRequestScreen({super.key});

  @override
  ConsumerState<MemberLoanRequestScreen> createState() => _MemberLoanRequestScreenState();
}

class _MemberLoanRequestScreenState extends ConsumerState<MemberLoanRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _interestController = TextEditingController();
  final _purposeController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isSubmitting = false;
  bool _interestInitialized = false;
  bool _hasContributions = true;
  bool _checkingContribs = true;
  Member? _member;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMember();
      _checkContributions();
    });
  }

  Future<void> _loadMember() async {
    final user = ref.read(currentUserProvider).state;
    if (user?.memberId == null) return;
    final repo = MemberRepository();
    final m = await repo.getMemberById(user!.memberId!);
    if (mounted) setState(() => _member = m);
  }

  Future<void> _checkContributions() async {
    final user = ref.read(currentUserProvider).state;
    if (user?.memberId == null) return;
    final repo = ContributionRepository();
    final total = await repo.getMemberTotalContributions(user!.memberId!);
    if (mounted) {
      setState(() {
        _hasContributions = total > 0;
        _checkingContribs = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _interestController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final currentUser = ref.read(currentUserProvider).state;
    if (currentUser?.memberId == null) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No linked member account'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      final memberRepo = MemberRepository();
      final member = await memberRepo.getMemberById(currentUser!.memberId!);

      final loanRequest = LoanRequest(
        memberId: currentUser.memberId!,
        memberName: member?.name ?? currentUser.username,
        amount: double.parse(_amountController.text),
        interestRate: double.parse(_interestController.text),
        notes: _purposeController.text,
        dueDate: _dueDate,
        status: LoanRequestStatus.pending,
        requestedAt: DateTime.now(),
      );

      final repo = LoanRequestRepository();
      await repo.createLoanRequest(loanRequest);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PendingApprovalDialog(
          title: 'Loan Request Submitted',
          message: 'Your loan request has been received. Please wait for admin review and approval.',
        ),
      ).then((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit request: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settingsAsync = ref.watch(settingsProvider);
    final defaultInterest = settingsAsync.valueOrNull?.loanInterestPercent ?? 10.0;

    if (!_interestInitialized && _interestController.text.isEmpty && defaultInterest > 0) {
      _interestController.text = defaultInterest.toStringAsFixed(1);
      _interestInitialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Loan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Member info
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
                            const Gap(4),
                            Row(
                              children: [
                                _chip('${_member!.headsCount} head${_member!.headsCount > 1 ? 's' : ''}', AppColors.primary),
                                const Gap(8),
                                _chip('Balance: ${CurrencyFormatter.format(_member!.balance ?? 0)}', AppColors.success),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Gap(16),

              // Contribution check
              if (_checkingContribs)
                const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ))
              else if (!_hasContributions)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined, color: AppColors.warning, size: 24),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('No Contributions Recorded',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning, fontSize: 14)),
                            const Gap(4),
                            Text(
                              'You need at least one contribution before applying for a loan.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
              // Loan amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Loan Amount (${CurrencyFormatter.currencySymbol})',
                  prefixText: '${CurrencyFormatter.currencySymbol} ',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter amount';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Please enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Interest rate
              TextFormField(
                controller: _interestController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Interest Rate (%)',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                  helperText: 'Typical range: 5-10%',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter interest rate';
                  if (double.tryParse(value) == null || double.parse(value) < 0) return 'Please enter valid rate';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Purpose
              TextFormField(
                controller: _purposeController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  border: OutlineInputBorder(),
                  helperText: 'Brief description of loan purpose',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter purpose';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Due date
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today, color: AppColors.secondary, size: 20),
                ),
                title: const Text('Due Date', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                trailing: TextButton(
                  onPressed: _selectDueDate,
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 8),

              // Repayment summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Repayment Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Interest ${_interestController.text.isNotEmpty ? _interestController.text : defaultInterest.toStringAsFixed(1)}%  •  Due ${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Due in ${_dueDate.difference(DateTime.now()).inDays} days',
                        style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Info note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        SizedBox(width: 8),
                        Text('Important Notes',
                          style: TextStyle(color: AppColors.info, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Your request will be reviewed by admin\n'
                      '• Approval depends on fund availability\n'
                      '• You can only have one active loan at a time\n'
                      '• Interest will be added to repayment amount',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Request', style: TextStyle(fontSize: 16)),
                ),
              ),
              ], // else
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
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
