import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/payment_request.dart';
import '../../data/repositories/payment_request_repository.dart';
import '../../providers/auth_provider.dart';

final pendingPaymentRequestsProvider = StreamProvider.autoDispose<List<PaymentRequest>>((ref) {
  return FirebaseService.firestore
      .collection('payment_requests')
      .where('status', isEqualTo: 'pending')
      .orderBy('requestDate', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => PaymentRequest.fromMap({...doc.data(), 'id': doc.id}))
          .toList());
});

class TreasurerDashboardScreen extends ConsumerStatefulWidget {
  const TreasurerDashboardScreen({super.key});

  @override
  ConsumerState<TreasurerDashboardScreen> createState() => _TreasurerDashboardScreenState();
}

class _TreasurerDashboardScreenState extends ConsumerState<TreasurerDashboardScreen> {
  final PaymentRequestRepository _repo = PaymentRequestRepository();

  Future<void> _confirmBankReceived(PaymentRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bank Receipt'),
        content: Text(
          'Have you received ${CurrencyFormatter.format(request.amount)} from the member for this ${request.type.name} request?\n\nThe admin will be notified.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm Received'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = ref.read(currentUserProvider);
    final success = await _repo.confirmBankReceived(
      request.id!,
      confirmedBy: user.state?.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Bank receipt confirmed. Admin notified.' : 'Already confirmed or failed.'),
          backgroundColor: success ? Colors.green : AppColors.error,
        ),
      );
    }
  }

  Future<String> _getMemberName(String memberId) async {
    try {
      final doc = await FirebaseService.firestore.collection('members').doc(memberId).get();
      if (doc.exists) return doc.data()?['name'] ?? 'Unknown';
    } catch (_) {}
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests = ref.watch(pendingPaymentRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Treasurer Dashboard')),
      body: pendingRequests.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
                  const SizedBox(height: 16),
                  const Text('No pending payment requests', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('New requests will appear here', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            );
          }

          final pending = requests.where((r) => !r.bankConfirmed).toList();
          final confirmed = requests.where((r) => r.bankConfirmed).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('Pending Bank Confirmation', pending.length, AppColors.warning),
              const SizedBox(height: 8),
              if (pending.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('All payments have been confirmed.'),
                  ),
                )
              else
                ...pending.map((req) => _buildRequestCard(req, needsConfirmation: true)),
              const SizedBox(height: 24),
              _buildSectionHeader('Confirmed (Awaiting Admin Approval)', confirmed.length, AppColors.success),
              const SizedBox(height: 8),
              if (confirmed.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No confirmed payments yet.'),
                  ),
                )
              else
                ...confirmed.map((req) => _buildRequestCard(req, needsConfirmation: false)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildRequestCard(PaymentRequest request, {required bool needsConfirmation}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  request.type == PaymentType.contribution ? Icons.attach_money : Icons.account_balance,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: FutureBuilder<String>(
                  future: _getMemberName(request.memberId),
                  builder: (_, snap) => Text(snap.data ?? 'Loading...', style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: request.type == PaymentType.contribution
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.type.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: request.type == PaymentType.contribution ? Colors.blue : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(CurrencyFormatter.format(request.amount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${request.requestDate.month}/${request.requestDate.day}/${request.requestDate.year}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            if (request.bankConfirmed && request.bankConfirmedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Confirmed on ${request.bankConfirmedAt!.month}/${request.bankConfirmedAt!.day}',
                    style: const TextStyle(fontSize: 11, color: AppColors.success),
                  ),
                ],
              ),
            ],
            if (needsConfirmation) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmBankReceived(request),
                  icon: const Icon(Icons.account_balance, size: 16),
                  label: const Text('Confirm Bank Received'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
