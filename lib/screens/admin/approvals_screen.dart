import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../data/models/payment_request.dart';
import '../../data/models/loan_request.dart';
import '../../data/repositories/payment_request_repository.dart';
import '../../data/repositories/loan_request_repository.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';

final pendingPaymentsProvider = FutureProvider<List<PaymentRequest>>((ref) async {
  final repo = PaymentRequestRepository();
  return await repo.getPendingPaymentRequests();
});

final pendingLoansProvider = FutureProvider<List<LoanRequest>>((ref) async {
  final repo = LoanRequestRepository();
  return await repo.getPendingLoanRequests();
});

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pending Approvals'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Payments'),
              Tab(text: 'Loans'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PendingPaymentsTab(),
            _PendingLoansTab(),
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
              return _PaymentApprovalCard(payment: payment, ref: ref);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading payments')),
    );
  }
}

class _PaymentApprovalCard extends StatelessWidget {
  final PaymentRequest payment;
  final WidgetRef ref;

  const _PaymentApprovalCard({required this.payment, required this.ref});

  @override
  Widget build(BuildContext context) {
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
                  'Member ${payment.memberId}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                    onPressed: () => _handleReject(context),
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
                    onPressed: () => _handleApprove(context),
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

  Future<void> _handleApprove(BuildContext context) async {
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

  Future<void> _handleReject(BuildContext context) async {
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
              return _LoanApprovalCard(loan: loan, ref: ref);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading loans')),
    );
  }
}

class _LoanApprovalCard extends StatelessWidget {
  final LoanRequest loan;
  final WidgetRef ref;

  const _LoanApprovalCard({required this.loan, required this.ref});

  @override
  Widget build(BuildContext context) {
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
                  'Member ${loan.memberId}',
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
                    onPressed: () => _handleReject(context),
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
                    onPressed: () => _handleApprove(context),
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

  Future<void> _handleApprove(BuildContext context) async {
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

  Future<void> _handleReject(BuildContext context) async {
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
