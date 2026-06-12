import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/firebase/firebase_service.dart';
import '../../providers/auth_provider.dart';
import '../../data/models/head_change_request.dart';
import '../../data/repositories/head_change_request_repository.dart';
import '../../data/repositories/member_repository.dart';

class MemberHeadChangeModal extends ConsumerStatefulWidget {
  const MemberHeadChangeModal({super.key});

  @override
  ConsumerState<MemberHeadChangeModal> createState() => _MemberHeadChangeModalState();
}

class _MemberHeadChangeModalState extends ConsumerState<MemberHeadChangeModal> {
  final _formKey = GlobalKey<FormState>();
  int _requestedHeads = 1;
  int _currentHeads = 0;
  bool _isSubmitting = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  Future<void> _loadMemberData() async {
    final user = ref.read(currentUserProvider).state;
    if (user?.memberId == null) return;

    final memberRepo = MemberRepository();
    final member = await memberRepo.getMemberById(user!.memberId!);
    if (member != null && mounted) {
      setState(() {
        _currentHeads = member.headsCount;
        _requestedHeads = member.headsCount;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  String? _headsValidator(String? value) {
    if (value == null || value.isEmpty) return 'Please enter number of heads';
    final parsed = int.tryParse(value);
    if (parsed == null) return 'Please enter a valid number';
    if (parsed < 1) return 'Minimum is 1 head';
    if (parsed > 100) return 'Maximum is 100 heads';
    if (parsed == _currentHeads) return 'Must be different from current heads';
    return null;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider).state;
    final memberId = user?.memberId;
    if (memberId == null) return;

    setState(() => _isSubmitting = true);

    try {
      // Check head change rules
      final now = DateTime.now();
      final isJanuary = now.month == 1;

      final contribSnapshot = await FirebaseService.firestore
          .collection('contributions')
          .where('memberId', isEqualTo: memberId)
          .get();

      final paymentSnapshot = await FirebaseService.firestore
          .collection('payment_requests')
          .where('memberId', isEqualTo: memberId)
          .get();

      final hasContributions = contribSnapshot.docs.isNotEmpty ||
          paymentSnapshot.docs.any((d) {
            final data = d.data();
            return data['status'] == 'approved' && data['type'] == 'contribution';
          });

      if (hasContributions && !isJanuary) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _showValidationDialog(context);
        }
        return;
      }

      final repo = HeadChangeRequestRepository();
      final memberRepo = MemberRepository();
      final member = await memberRepo.getMemberById(memberId);

      final request = HeadChangeRequest(
        memberId: memberId,
        memberName: member?.name ?? user?.username ?? '',
        currentHeads: _currentHeads,
        requestedHeads: _requestedHeads,
        status: HeadChangeStatus.pending,
        requestedAt: DateTime.now(),
      );

      await repo.createHeadChangeRequest(request);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Head change request submitted! Waiting for admin approval'),
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

  void _showValidationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Head Change Not Allowed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Head changes for members with existing contributions are only allowed in January (start of the year reset). '
          'Please wait until January to submit your request.\n\n'
          'New members with no contributions can change heads at any time.',
          style: TextStyle(color: AppColors.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Change Heads',
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
                      const SizedBox(height: 24),

                      // Current heads display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Heads',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.people, color: AppColors.secondary, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  '$_currentHeads ${_currentHeads == 1 ? 'head' : 'heads'}',
                                  style: const TextStyle(
                                    color: AppColors.secondary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // New heads input
                      TextFormField(
                        initialValue: _requestedHeads.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Requested Heads',
                          prefixIcon: Icon(Icons.people_outline),
                        ),
                        keyboardType: TextInputType.number,
                        validator: _headsValidator,
                        onChanged: (v) {
                          final parsed = int.tryParse(v);
                          if (parsed != null) {
                            setState(() => _requestedHeads = parsed);
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.info.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.info.withAlpha(77)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.compare_arrows, color: AppColors.info, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Change Summary',
                                  style: TextStyle(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _summaryRow('Current', '$_currentHeads ${_currentHeads == 1 ? 'head' : 'heads'}'),
                            const SizedBox(height: 6),
                            _summaryRow('Requested', '$_requestedHeads ${_requestedHeads == 1 ? 'head' : 'heads'}'),
                            const SizedBox(height: 6),
                            _summaryRow(
                              'Difference',
                              _requestedHeads >= _currentHeads
                                  ? '+${_requestedHeads - _currentHeads}'
                                  : '-${_currentHeads - _requestedHeads}',
                              highlight: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

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
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.info : AppColors.textPrimary,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
