import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/contribution.dart';
import '../../data/models/member.dart';
import '../../providers/fund_provider.dart';
import '../../providers/members_provider.dart';

class NewContributionModal extends ConsumerStatefulWidget {
  const NewContributionModal({super.key});

  @override
  ConsumerState<NewContributionModal> createState() => _NewContributionModalState();
}

class _NewContributionModalState extends ConsumerState<NewContributionModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedMemberId;
  final DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  Member? get _selectedMember {
    final members = ref.watch(membersProvider).valueOrNull ?? [];
    return members.cast<Member?>().firstWhere(
      (m) => m?.id == _selectedMemberId,
      orElse: () => null,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate() || _selectedMemberId == null) return;

    setState(() => _isSaving = true);

    try {
      final contribution = Contribution(
        memberId: _selectedMemberId!,
        amount: double.parse(_amountController.text),
        date: _selectedDate,
        month: _selectedDate.month,
        year: _selectedDate.year,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdBy: 'admin',
      );

      final repo = ref.read(fundRepositoryProvider);
      await repo.addContribution(contribution);
      ref.invalidate(totalFundProvider);
      ref.invalidate(membersProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add contribution: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: const BoxDecoration(
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
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments, color: AppColors.primary, size: 22),
                ),
                const Gap(14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Contribution',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Text('Record a manual contribution',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const Gap(24),
            members.when(
              data: (list) => DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Member',
                  prefixIcon: const Icon(Icons.person, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                ),
                items: list.map((member) {
                  return DropdownMenuItem(
                    value: member.id,
                    child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedMemberId = value),
                validator: (value) => value == null ? 'Select a member' : null,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading members'),
            ),
            if (_selectedMember != null) ...[
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textMuted.withAlpha(51)),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      Icons.people, 'Heads', '${_selectedMember!.headsCount}',
                      Icons.monetization_on, 'Per Head', CurrencyFormatter.format(_selectedMember!.amountPerHead),
                    ),
                    const Divider(height: 24, color: AppColors.textMuted),
                    Row(
                      children: [
                        const Icon(Icons.assignment, size: 16, color: AppColors.textMuted),
                        const Gap(8),
                        const Text('Total Required', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        const Spacer(),
                        Text(CurrencyFormatter.format(_selectedMember!.totalRequired),
                          style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, size: 16, color: AppColors.textMuted),
                        const Gap(8),
                        const Text('Credit Balance', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        const Spacer(),
                        Text(CurrencyFormatter.format(_selectedMember!.balance),
                          style: TextStyle(
                            color: _selectedMember!.balance > 0 ? AppColors.success : AppColors.textMuted,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const Gap(16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₱ ',
                prefixIcon: const Icon(Icons.attach_money, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surfaceAlt,
              ),
              keyboardType: TextInputType.number,
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
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: const Icon(Icons.notes, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surfaceAlt,
              ),
              maxLines: 2,
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Contribution',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon1, String label1, String value1, IconData icon2, String label2, String value2) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon1, size: 16, color: AppColors.textMuted),
              const Gap(8),
              Text(label1, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const Spacer(),
              Text(value1, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Row(
            children: [
              Icon(icon2, size: 16, color: AppColors.textMuted),
              const Gap(8),
              Text(label2, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const Spacer(),
              Text(value2, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
