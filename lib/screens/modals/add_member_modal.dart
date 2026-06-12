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
  final _emailController = TextEditingController();

  bool get _isEditing => widget.existingMember != null;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final m = widget.existingMember!;
      _nameController.text = m.name;
      _headsController.text = m.headsCount.toString();
      _amountController.text = m.amountPerHead.toStringAsFixed(2);
      _emailController.text = m.linkedEmail ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headsController.dispose();
    _amountController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final headsCount = int.parse(_headsController.text);
    final amountPerHead = double.parse(_amountController.text);
    final email = _emailController.text.trim();
    final linkedEmail = email.isEmpty ? null : email;

    final repo = ref.read(memberRepositoryProvider);

    try {
      if (_isEditing) {
        final member = widget.existingMember!;
        member.name = _nameController.text;
        member.headsCount = headsCount;
        member.amountPerHead = amountPerHead;
        member.totalRequired = headsCount * amountPerHead;
        member.linkedEmail = linkedEmail;
        await repo.updateMember(member);
      } else {
        final member = Member(
          name: _nameController.text,
          headsCount: headsCount,
          amountPerHead: amountPerHead,
          totalRequired: headsCount * amountPerHead,
          linkedEmail: linkedEmail,
          joinedAt: DateTime.now(),
        );
        await repo.addMember(member);
      }

      ref.invalidate(membersProvider);
      ref.invalidate(membersWithStatusProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save member: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (_isSaving) return;
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

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(memberRepositoryProvider);
      await repo.deleteMember(widget.existingMember!.id!);
      ref.invalidate(membersProvider);
      ref.invalidate(membersWithStatusProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e'), backgroundColor: AppColors.error),
        );
        setState(() => _isSaving = false);
      }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Edit Member' : 'Add Member',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                if (_isEditing && widget.existingMember!.displayId.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.existingMember!.displayId,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
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
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                hintText: 'For member self-registration',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final email = value.trim();
                if (!email.contains('@') || !email.contains('.')) {
                  return 'Please enter a valid email';
                }
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
                final parsed = int.tryParse(value);
                if (parsed == null) return 'Invalid number';
                if (parsed < 1) return 'Minimum is 1 head';
                if (parsed > 100) return 'Maximum is 100 heads';
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
                final parsed = double.tryParse(value);
                if (parsed == null) return 'Invalid amount';
                if (parsed <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
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
                  onPressed: _isSaving ? null : _delete,
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