import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../data/models/payment_request.dart';
import '../../data/models/loan_request.dart';
import '../../data/models/head_change_request.dart';
import '../../data/repositories/payment_request_repository.dart';
import '../../data/repositories/loan_request_repository.dart';
import '../../data/repositories/head_change_request_repository.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/members_provider.dart';
import '../../providers/auth_provider.dart';

final pendingPaymentsProvider = StreamProvider.autoDispose<List<PaymentRequest>>((ref) {
  return ref.watch(paymentRequestRepositoryProvider).watchPendingPaymentRequests();
});

final pendingLoansProvider = StreamProvider.autoDispose<List<LoanRequest>>((ref) {
  return ref.watch(loanRequestRepositoryProvider).watchPendingLoanRequests();
});

final pendingHeadChangesProvider = StreamProvider.autoDispose<List<HeadChangeRequest>>((ref) {
  return ref.watch(headChangeRequestRepositoryProvider).watchPendingHeadChangeRequests();
});

final memberNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final members = await ref.watch(memberRepositoryProvider).getAllMembers();
  return {for (var m in members) m.id!: m.name};
});

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pending Approvals'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Payments'),
              Tab(text: 'Loans'),
              Tab(text: 'Heads'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PendingPaymentsTab(),
            _PendingLoansTab(),
            _PendingHeadChangesTab(),
          ],
        ),
      ),
    );
  }
}

class _PendingPaymentsTab extends ConsumerWidget {
  const _PendingPaymentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(pendingPaymentsProvider);

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return const Center(
            child: Text('No pending payments'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingPaymentsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return _PaymentApprovalCard(payment: payment);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Error loading payments'),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ref.invalidate(pendingPaymentsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentApprovalCard extends ConsumerWidget {
  final PaymentRequest payment;

  const _PaymentApprovalCard({required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberNames = ref.watch(memberNamesProvider).valueOrNull ?? {};
    final memberName = memberNames[payment.memberId] ?? 'Member ${payment.memberId}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memberName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: payment.type == PaymentType.loan 
                            ? Colors.orange.withValues(alpha: 0.2) 
                            : Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        payment.type == PaymentType.loan ? 'Loan Repayment' : 'Contribution',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: payment.type == PaymentType.loan ? Colors.orange : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.format(payment.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Submitted: ${DateFormatter.format(payment.requestDate)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 12),
            if (payment.receiptPath != null)
              InkWell(
                onTap: () => _showReceiptImage(context),
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(payment.receiptPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(context, ref),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(context, ref),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Receipt',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Image.file(
              File(payment.receiptPath!),
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final repo = PaymentRequestRepository();
    await repo.approvePaymentRequest(payment.id!);
    
    ref.invalidate(pendingPaymentsProvider);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment approved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final notesController = TextEditingController();
    
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (shouldReject == true && context.mounted) {
      final repo = PaymentRequestRepository();
      await repo.rejectPaymentRequest(payment.id!, notes: notesController.text);
      
      ref.invalidate(pendingPaymentsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _PendingLoansTab extends ConsumerWidget {
  const _PendingLoansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(pendingLoansProvider);

    return loansAsync.when(
      data: (loans) {
        if (loans.isEmpty) {
          return const Center(
            child: Text('No pending loan requests'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingLoansProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: loans.length,
            itemBuilder: (context, index) {
              final loan = loans[index];
              return _LoanApprovalCard(loan: loan);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Error loading loans'),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ref.invalidate(pendingLoansProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanApprovalCard extends ConsumerWidget {
  final LoanRequest loan;

  const _LoanApprovalCard({required this.loan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberNames = ref.watch(memberNamesProvider).valueOrNull ?? {};
    final memberName = memberNames[loan.memberId] ?? 'Member ${loan.memberId}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  memberName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  CurrencyFormatter.format(loan.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 16),
            _InfoRow('Interest Rate', '${loan.interestRate}%'),
            const SizedBox(height: 4),
            _InfoRow('Due Date', DateFormatter.format(loan.dueDate)),
            const SizedBox(height: 4),
            _InfoRow('Requested', DateFormatter.format(loan.requestedAt)),
            const Divider(height: 16),
            Text(
              'Notes:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              loan.notes ?? 'No notes provided',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(context, ref),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(context, ref),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final repo = LoanRequestRepository();
    await repo.approveLoanRequest(loan.id!);
    
    ref.invalidate(pendingLoansProvider);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan request approved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final notesController = TextEditingController();
    
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Loan Request'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (shouldReject == true && context.mounted) {
      final repo = LoanRequestRepository();
      await repo.rejectLoanRequest(loan.id!, notes: notesController.text);
      
      ref.invalidate(pendingLoansProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan request rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _PendingHeadChangesTab extends ConsumerWidget {
  const _PendingHeadChangesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headsAsync = ref.watch(pendingHeadChangesProvider);

    return headsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Text('No pending head change requests'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingHeadChangesProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _HeadChangeApprovalCard(request: request);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Error loading head change requests'),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ref.invalidate(pendingHeadChangesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadChangeApprovalCard extends ConsumerWidget {
  final HeadChangeRequest request;

  const _HeadChangeApprovalCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberNames = ref.watch(memberNamesProvider).valueOrNull ?? {};
    final memberName = memberNames[request.memberId] ?? 'Member ${request.memberId}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memberName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Column(
                          children: [
                            const Text('Current', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('${request.currentHeads}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.arrow_forward, color: Colors.grey),
                        ),
                        Column(
                          children: [
                            const Text('Requested', style: TextStyle(color: Colors.orange, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('${request.requestedHeads}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${request.requestedHeads - request.currentHeads >= 0 ? '+' : ''}${request.requestedHeads - request.currentHeads}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: request.requestedHeads >= request.currentHeads ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 16),
            _InfoRow('Current Heads', '${request.currentHeads}'),
            const SizedBox(height: 4),
            _InfoRow('Requested Heads', '${request.requestedHeads}'),
            const SizedBox(height: 4),
            _InfoRow('Difference', '${request.requestedHeads - request.currentHeads >= 0 ? '+' : ''}${request.requestedHeads - request.currentHeads}'),
            const SizedBox(height: 4),
            _InfoRow('Requested', DateFormatter.format(request.requestedAt)),
            const Divider(height: 16),
            Text(
              'Notes:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              request.reason ?? 'No reason provided',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(context, ref),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(context, ref),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final repo = HeadChangeRequestRepository();
    final user = ref.read(currentUserProvider).state;
    await repo.approveHeadChangeRequest(request.id!,
      processedBy: user?.username ?? 'Admin',
    );

    ref.invalidate(pendingHeadChangesProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Head change approved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final notesController = TextEditingController();

    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Head Change'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (shouldReject == true && context.mounted) {
      final repo = HeadChangeRequestRepository();
      final user = ref.read(currentUserProvider).state;
      await repo.rejectHeadChangeRequest(request.id!,
        processedBy: user?.username ?? 'Admin',
        notes: notesController.text,
      );

      ref.invalidate(pendingHeadChangesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Head change rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
