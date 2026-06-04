import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/member.dart';
import '../../providers/members_provider.dart';
import '../../providers/members_with_status_provider.dart';

class AddMemberModal extends ConsumerStatefulWidget {
  final Member? existingMember;

  const AddMemberModal({super.key, this.existingMember});

  @override
  ConsumerState<AddMemberModal> createState() => _AddMemberModalState();
}

class _AddMemberModalState extends ConsumerState<AddMemberModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _headsController = TextEditingController();
  final _amountController = TextEditingController();

  bool get _isEditing => widget.existingMember != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final m = widget.existingMember!;
      _nameController.text = m.name;
      _headsController.text = m.headsCount.toString();
      _amountController.text = m.amountPerHead.toString();
    }
  }

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

      final repo = ref.read(memberRepositoryProvider);

      if (_isEditing) {
        final member = widget.existingMember!;
        member.name = _nameController.text;
        member.headsCount = headsCount;
        member.amountPerHead = amountPerHead;
        member.totalRequired = headsCount * amountPerHead;
        await repo.updateMember(member);
      } else {
        final member = Member(
          name: _nameController.text,
          headsCount: headsCount,
          amountPerHead: amountPerHead,
          totalRequired: headsCount * amountPerHead,
          joinedAt: DateTime.now(),
        );
        await repo.addMember(member);
      }

      ref.invalidate(membersProvider);
      ref.invalidate(membersWithStatusProvider);

      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Member'),
        content: Text('Remove ${widget.existingMember!.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(memberRepositoryProvider);
      await repo.deleteMember(widget.existingMember!.id!);
      ref.invalidate(membersProvider);
      ref.invalidate(membersWithStatusProvider);
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
              _isEditing ? 'Edit Member' : 'Add Member',
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
                child: Text(
                  _isEditing ? 'Save Changes' : 'Add Member',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_isEditing) ...[
              const Gap(12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Member'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ],
            const Gap(24),
          ],
        ),
      ),
    );
  }
}