import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/loan_request.dart';
import '../../data/repositories/loan_request_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../core/utils/currency_formatter.dart';

class MemberLoanRequestModal extends ConsumerStatefulWidget {
  const MemberLoanRequestModal({super.key});

  @override
  ConsumerState<MemberLoanRequestModal> createState() => _MemberLoanRequestModalState();
}

class _MemberLoanRequestModalState extends ConsumerState<MemberLoanRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _interestRateController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isSubmitting = false;
  bool _hasContributions = true;
  bool _checkingContribs = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkContributions());
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
    _interestRateController.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider).state;
    if (user?.memberId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = LoanRequestRepository();
      final memberRepo = MemberRepository();
      final member = await memberRepo.getMemberById(user!.memberId!);

      final request = LoanRequest(
        memberId: user.memberId!,
        memberName: member?.name ?? 'Unknown',
        amount: double.parse(_amountController.text),
        interestRate: double.parse(_interestRateController.text),
        dueDate: _dueDate,
        status: LoanRequestStatus.pending,
        requestedAt: DateTime.now(),
      );

      await repo.createLoanRequest(request);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan request submitted! Waiting for admin approval'),
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
    final settingsAsync = ref.watch(settingsProvider);
    final defaultInterest = settingsAsync.valueOrNull?.loanInterestPercent ?? 10.0;

    if (_interestRateController.text.isEmpty && defaultInterest > 0) {
      _interestRateController.text = defaultInterest.toStringAsFixed(1);
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      'Request Loan',
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
                if (_checkingContribs)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ))
                else if (!_hasContributions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(Icons.payments_outlined, size: 64, color: AppColors.warning.withAlpha(150)),
                        const SizedBox(height: 16),
                        Text(
                          'No Contributions Recorded',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You need to have at least one contribution before applying for a loan. Please make a payment first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Loan Amount (${CurrencyFormatter.currencySymbol})',
                    prefixText: '${CurrencyFormatter.currencySymbol} ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter valid amount';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _interestRateController,
                  decoration: const InputDecoration(
                    labelText: 'Interest Rate (%)',
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter interest rate';
                    }
                    final rate = double.tryParse(value);
                    if (rate == null || rate < 0) {
                      return 'Please enter valid rate';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due Date'),
                  subtitle: Text(
                    '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: TextButton(
                    onPressed: _selectDueDate,
                    child: const Text('Change'),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.info, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Note',
                            style: TextStyle(
                              color: AppColors.info,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your loan request will be reviewed by the admin. You will be notified once it\'s processed.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Request'),
                  ),
                ),
                ], // else block
              ],
            ),
          ),
        ),
      ),
    );
  }
}
