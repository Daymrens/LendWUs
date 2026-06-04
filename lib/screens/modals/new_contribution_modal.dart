import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/contribution.dart';
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

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedMemberId != null) {
      final contribution = Contribution(
        memberId: _selectedMemberId!,
        amount: double.parse(_amountController.text),
        date: _selectedDate,
        month: _selectedDate.month,
        year: _selectedDate.year,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      final repo = ref.read(fundRepositoryProvider);
      await repo.addContribution(contribution);
      ref.invalidate(totalFundProvider);

      if (mounted) Navigator.pop(context);
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
            Text(
              'New Contribution',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const Gap(24),
            members.when(
              data: (list) => DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Member'),
                initialValue: _selectedMemberId,
                items: list.map((member) {
                  return DropdownMenuItem(
                    value: member.id,
                    child: Text(member.name),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedMemberId = value),
                validator: (value) => value == null ? 'Select a member' : null,
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading members'),
            ),
            const Gap(16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter amount';
                if (double.tryParse(value) == null) return 'Invalid amount';
                return null;
              },
            ),
            const Gap(16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Add Contribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}
