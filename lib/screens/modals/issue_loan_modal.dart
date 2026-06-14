import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/loan.dart';
import '../../data/models/member.dart';
import '../../providers/loans_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/fund_summary_provider.dart';
import '../../providers/settings_provider.dart';

class IssueLoanModal extends ConsumerStatefulWidget {
  const IssueLoanModal({super.key});

  @override
  ConsumerState<IssueLoanModal> createState() => _IssueLoanModalState();
}

class _IssueLoanModalState extends ConsumerState<IssueLoanModal> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  String? _selectedMemberId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String? _errorMessage;
  bool _interestInitialized = false;
  bool _isSubmitting = false;

  Member? get _selectedMember {
    final members = ref.watch(membersProvider).valueOrNull ?? [];
    return members.cast<Member?>().firstWhere(
      (m) => m?.id == _selectedMemberId,
      orElse: () => null,
    );
  }

  @override
  void dispose() {
    _principalController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate() || _selectedMemberId == null) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    final principal = double.parse(_principalController.text);
    final interestRate = double.parse(_interestController.text) / 100;

    final loanRepo = ref.read(loanRepositoryProvider);

    try {
      if (principal <= 0) {
        setState(() {
          _errorMessage = 'Loan amount must be greater than zero';
          _isSubmitting = false;
        });
        return;
      }

      final member = _selectedMember;
      if (member == null || !member.isActive) {
        setState(() {
          _errorMessage = 'Member is not active';
          _isSubmitting = false;
        });
        return;
      }

      if (!_dueDate.isAfter(DateTime.now())) {
        setState(() {
          _errorMessage = 'Due date must be in the future';
          _isSubmitting = false;
        });
        return;
      }

      final fundSummary = await ref.read(fundSummaryProvider.future);
      if (principal > fundSummary.availableToLoan) {
        setState(() {
          _errorMessage = 'Insufficient fund balance. Available: ${CurrencyFormatter.format(fundSummary.availableToLoan)}';
          _isSubmitting = false;
        });
        return;
      }

      final hasActive = await loanRepo.hasActiveLoan(_selectedMemberId!);
      if (hasActive) {
        setState(() {
          _errorMessage = 'Member already has an unpaid loan';
          _isSubmitting = false;
        });
        return;
      }

      final loan = Loan(
        memberId: _selectedMemberId!,
        principal: principal,
        interestRate: interestRate,
        issuedDate: DateTime.now(),
        dueDate: _dueDate,
      );

      await loanRepo.addLoan(loan);
      ref.invalidate(totalLoansProvider);
      ref.invalidate(fundSummaryProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not issue loan: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider);
    final fundSummary = ref.watch(fundSummaryProvider);
    final defaultInterest = ref.watch(settingsProvider).valueOrNull?.loanInterestPercent ?? 10.0;

    if (!_interestInitialized && _interestController.text.isEmpty && defaultInterest > 0) {
      _interestController.text = defaultInterest.toStringAsFixed(1);
      _interestInitialized = true;
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance, color: AppColors.secondary, size: 22),
                ),
                const Gap(14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Issue Loan',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
                    fundSummary.when(
                      data: (summary) => Text('Available: ${CurrencyFormatter.format(summary.availableToLoan)}',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      loading: () => Text('Checking balance...',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      error: (_, __) => const SizedBox(),
                    ),
                  ],
                ),
              ],
            ),
            const Gap(24),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withAlpha(128)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.warning, size: 20),
                    const Gap(8),
                    Expanded(
                      child: Text(_errorMessage!,
                        style: const TextStyle(color: AppColors.warning, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            members.when(
              data: (list) {
                final activeMembers = list.where((m) => m.isActive).toList();
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Member',
                    prefixIcon: const Icon(Icons.person, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                  ),
                  items: activeMembers.map((member) {
                    return DropdownMenuItem(
                      value: member.id,
                      child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedMemberId = value),
                  validator: (value) => value == null ? 'Select a member' : null,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading members'),
            ),
            if (_selectedMember != null) ...[
              const Gap(12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textMuted.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, size: 16, color: AppColors.textMuted),
                    const Gap(8),
                    Text('${_selectedMember!.name} · ${_selectedMember!.headsCount} head(s)',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const Spacer(),
                    Text('Req: ${CurrencyFormatter.format(_selectedMember!.totalRequired)}',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
            const Gap(16),
            TextFormField(
              controller: _principalController,
              decoration: InputDecoration(
                labelText: 'Principal Amount',
                prefixText: '₱ ',
                prefixIcon: const Icon(Icons.attach_money, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surfaceAlt,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter amount';
                final parsed = double.tryParse(value);
                if (parsed == null) return 'Invalid amount';
                if (parsed <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const Gap(16),
            TextFormField(
              controller: _interestController,
              decoration: InputDecoration(
                labelText: 'Interest Rate',
                suffixText: '%',
                prefixIcon: const Icon(Icons.percent, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surfaceAlt,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter rate';
                final parsed = double.tryParse(value);
                if (parsed == null) return 'Invalid rate';
                if (parsed < 0) return 'Rate cannot be negative';
                if (parsed > 100) return 'Rate cannot exceed 100%';
                return null;
              },
            ),
            const Gap(16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.textMuted.withAlpha(51)),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(Icons.calendar_today, size: 20, color: AppColors.textMuted),
                title: Text('Due Date', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                subtitle: Text('${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _dueDate = date);
                  }
                },
              ),
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Issue Loan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}
