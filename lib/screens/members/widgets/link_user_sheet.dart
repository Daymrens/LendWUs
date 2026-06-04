import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/members_provider.dart';

class LinkUserSheet extends ConsumerStatefulWidget {
  final String memberId;
  final String memberName;
  final String? currentEmail;

  const LinkUserSheet({
    super.key,
    required this.memberId,
    required this.memberName,
    this.currentEmail,
  });

  @override
  ConsumerState<LinkUserSheet> createState() => _LinkUserSheetState();
}

class _LinkUserSheetState extends ConsumerState<LinkUserSheet> {
  final _emailController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentEmail != null) {
      _emailController.text = widget.currentEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isSaving = true);

    final repo = ref.read(memberRepositoryProvider);
    await repo.updateMemberLinkedEmail(widget.memberId, email);
    ref.invalidate(membersProvider);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$email linked to ${widget.memberName}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _unlink() async {
    setState(() => _isSaving = true);

    final repo = ref.read(memberRepositoryProvider);
    await repo.updateMemberLinkedEmail(widget.memberId, null);
    ref.invalidate(membersProvider);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User unlinked from member'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Link User to ${widget.memberName}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          const Text(
            'Enter the email of the user to link them to this member:',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const Gap(20),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            enabled: !_isSaving,
            onFieldSubmitted: (_) => _save(),
          ),
          const Gap(24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Link User',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          if (widget.currentEmail != null) ...[
            const Gap(12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _unlink,
                icon: const Icon(Icons.link_off),
                label: const Text('Unlink'),
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
    );
  }
}