import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/member.dart';
import '../../providers/members_provider.dart';

class AddMemberModal extends ConsumerStatefulWidget {
  const AddMemberModal({super.key});

  @override
  ConsumerState<AddMemberModal> createState() => _AddMemberModalState();
}

class _AddMemberModalState extends ConsumerState<AddMemberModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _headsController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _headsController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final headsCount = int.parse(_headsController.text);
      final amountPerHead = double.parse(_amountController.text);

      final member = Member(
        name: _nameController.text,
        headsCount: headsCount,
        amountPerHead: amountPerHead,
        totalRequired: headsCount * amountPerHead,
        joinedAt: DateTime.now(),
      );

      final repo = ref.read(memberRepositoryProvider);
      await repo.addMember(member);
      ref.invalidate(membersProvider);

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'Add Member',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const Gap(24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Member Name'),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter name';
                return null;
              },
            ),
            const Gap(16),
            TextFormField(
              controller: _headsController,
              decoration: const InputDecoration(labelText: 'Number of Heads'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter heads';
                if (int.tryParse(value) == null) return 'Invalid number';
                return null;
              },
            ),
            const Gap(16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount per Head'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter amount';
                if (double.tryParse(value) == null) return 'Invalid amount';
                return null;
              },
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
                  'Add Member',
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
