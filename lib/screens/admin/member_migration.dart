import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/firebase/firebase_service.dart';
import '../../providers/members_provider.dart';

class MemberMigrationScreen extends ConsumerStatefulWidget {
  const MemberMigrationScreen({super.key});

  @override
  ConsumerState<MemberMigrationScreen> createState() => _MemberMigrationScreenState();
}

class _MemberMigrationScreenState extends ConsumerState<MemberMigrationScreen> {
  String? _sourceMemberId;
  String? _targetMemberId;
  bool _processing = false;
  String? _result;

  Future<void> _transfer() async {
    if (_sourceMemberId == null || _targetMemberId == null) return;
    if (_sourceMemberId == _targetMemberId) {
      setState(() => _result = 'Source and target must be different');
      return;
    }
    setState(() { _processing = true; _result = null; });
    try {
      final firestore = FirebaseService.firestore;

      final contribSnapshot = await firestore
          .collection('contributions')
          .where('memberId', isEqualTo: _sourceMemberId)
          .get();
      final batch = firestore.batch();
      for (final doc in contribSnapshot.docs) {
        batch.update(doc.reference, {'memberId': _targetMemberId});
      }

      final loanSnapshot = await firestore
          .collection('loans')
          .where('memberId', isEqualTo: _sourceMemberId)
          .get();
      for (final doc in loanSnapshot.docs) {
        batch.update(doc.reference, {'memberId': _targetMemberId});
      }

      final payReqSnapshot = await firestore
          .collection('payment_requests')
          .where('memberId', isEqualTo: _sourceMemberId)
          .get();
      for (final doc in payReqSnapshot.docs) {
        batch.update(doc.reference, {'memberId': _targetMemberId});
      }

      final loanReqSnapshot = await firestore
          .collection('loan_requests')
          .where('memberId', isEqualTo: _sourceMemberId)
          .get();
      for (final doc in loanReqSnapshot.docs) {
        batch.update(doc.reference, {'memberId': _targetMemberId});
      }

      final headReqSnapshot = await firestore
          .collection('head_change_requests')
          .where('memberId', isEqualTo: _sourceMemberId)
          .get();
      for (final doc in headReqSnapshot.docs) {
        batch.update(doc.reference, {'memberId': _targetMemberId});
      }

      final userSnapshot = await firestore
          .collection('users')
          .where('memberId', isEqualTo: _sourceMemberId)
          .get();
      for (final doc in userSnapshot.docs) {
        batch.update(doc.reference, {'memberId': _targetMemberId});
      }

      await batch.commit();
      setState(() => _result = 'Data transferred successfully');
    } catch (e) {
      setState(() => _result = 'Transfer failed: $e');
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Member Migration')),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Transfer all records from one member to another.',
                style: TextStyle(color: AppColors.textMuted)),
              const Gap(24),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Source Member'),
                items: members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                onChanged: (v) => setState(() => _sourceMemberId = v),
              ),
              const Gap(16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Target Member'),
                items: members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                onChanged: (v) => setState(() => _targetMemberId = v),
              ),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processing ? null : _transfer,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                  child: _processing
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Transfer Data'),
                ),
              ),
              if (_result != null) ...[
                const Gap(16),
                Text(_result!, style: TextStyle(
                  color: _result!.contains('failed') ? AppColors.error : AppColors.success,
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
