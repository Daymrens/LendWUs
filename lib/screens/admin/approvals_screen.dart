import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/loan_request.dart';
import '../../data/models/head_change_request.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/members_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/firebase/firebase_service.dart';
import '../../widgets/receipt_image.dart';
import '../../data/repositories/loan_receipt_repository.dart';
import '../../data/models/loan_receipt.dart';
import '../../core/widgets/lendwus_logo.dart';

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

class _PaymentApprovalCard extends ConsumerStatefulWidget {
  final PaymentRequest payment;

  const _PaymentApprovalCard({required this.payment});

  @override
  ConsumerState<_PaymentApprovalCard> createState() => _PaymentApprovalCardState();
}

class _PaymentApprovalCardState extends ConsumerState<_PaymentApprovalCard> {
  bool _busy = false;

  PaymentRequest get payment => widget.payment;

  @override
  Widget build(BuildContext context) {
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
            if (payment.receiptUrl != null || payment.receiptPath != null)
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
                    child: ReceiptImage(
                      receiptUrl: payment.receiptUrl,
                      receiptPath: payment.receiptPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _handleReject(context),
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
                    onPressed: _busy ? null : () => _handleApprove(context),
                    icon: _busy
                        ? const SizedBox(
                            height: 14, width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
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
            ReceiptImage(
              receiptUrl: payment.receiptUrl,
              receiptPath: payment.receiptPath,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove(BuildContext context) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Approve Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Approve this ${payment.type == PaymentType.contribution ? "contribution" : "repayment"} payment of ${CurrencyFormatter.format(payment.amount)}? This will record the payment and cannot be undone.',
          style: TextStyle(color: AppColors.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final repo = ref.read(paymentRequestRepositoryProvider);
    final user = ref.read(currentUserProvider).state;

    try {
      final approved = await repo.approvePaymentRequest(
        payment.id!,
        approvedBy: user?.username ?? 'Admin',
      );

      ref.invalidate(pendingPaymentsProvider);

      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? 'Payment approved' : 'Payment already processed'),
            backgroundColor: approved ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleReject(BuildContext context) async {
    if (_busy) return;
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

    if (shouldReject != true) {
      notesController.dispose();
      return;
    }
    if (!mounted) {
      notesController.dispose();
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(paymentRequestRepositoryProvider);
    try {
      final rejected = await repo.rejectPaymentRequest(payment.id!, notes: notesController.text);
      ref.invalidate(pendingPaymentsProvider);

      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rejected ? 'Payment rejected' : 'Payment already processed'),
            backgroundColor: rejected ? Colors.red : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      notesController.dispose();
      if (mounted) setState(() => _busy = false);
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

class _LoanApprovalCard extends ConsumerStatefulWidget {
  final LoanRequest loan;

  const _LoanApprovalCard({required this.loan});

  @override
  ConsumerState<_LoanApprovalCard> createState() => _LoanApprovalCardState();
}

class _LoanApprovalCardState extends ConsumerState<_LoanApprovalCard> {
  bool _busy = false;

  LoanRequest get loan => widget.loan;

  @override
  Widget build(BuildContext context) {
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
                    onPressed: _busy ? null : () => _handleReject(context),
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
                    onPressed: _busy ? null : () => _handleApprove(context),
                    icon: _busy
                        ? const SizedBox(
                            height: 14, width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
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
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Approve Loan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Approve loan of ${CurrencyFormatter.format(loan.amount)} for ${loan.memberName ?? loan.memberId}? This will disburse the loan and generate a receipt.',
          style: TextStyle(color: AppColors.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      // Pre-check available funds
      final firestore = FirebaseService.firestore;
      final principal = loan.amount;
      if (principal > 0) {
        final [contribSnap, loanSnap, repaySnap] = await Future.wait([
          firestore.collection('contributions').get(),
          firestore.collection('loans').get(),
          firestore.collection('repayments').get(),
        ]);
        final totalContributions = contribSnap.docs.fold<double>(0.0, (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
        final totalLoansIssued = loanSnap.docs.fold<double>(0.0, (s, d) => s + ((d.data()['principal'] as num?)?.toDouble() ?? 0));
        final totalRepayments = repaySnap.docs.fold<double>(0.0, (s, d) => s + ((d.data()['amountPaid'] as num?)?.toDouble() ?? 0));
        final fundBalance = totalContributions - totalLoansIssued + totalRepayments;

        final repayByLoan = <String, double>{};
        for (final d in repaySnap.docs) {
          final r = d.data();
          final loanId = r['loanId'] as String?;
          final amount = (r['amountPaid'] as num?)?.toDouble() ?? 0;
          repayByLoan.update(loanId!, (v) => v + amount, ifAbsent: () => amount);
        }
        double outstanding = 0;
        for (final d in loanSnap.docs) {
          final l = d.data();
          if (l['isFullyRepaid'] == true) continue;
          final p = (l['principal'] as num?)?.toDouble() ?? 0;
          final rate = (l['interestRate'] as num?)?.toDouble() ?? 0;
          final repaid = repayByLoan[d.id] ?? 0;
          final totalDue = p + (p * rate);
          final remaining = totalDue - repaid;
          if (remaining > 0) outstanding += remaining;
        }
        final availableToLoan = fundBalance - outstanding;

        if (principal > availableToLoan) {
          setState(() => _busy = false);
          if (!context.mounted) return;
          final repo = ref.read(loanRequestRepositoryProvider);
          await repo.rejectLoanRequest(loan.id!, notes: 'Insufficient fund balance — the fund does not have enough available cash to cover this loan. Please wait for more contributions to come in before re-applying.');
          ref.invalidate(pendingLoansProvider);
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text('Loan Rejected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insufficient fund balance — the fund does not have enough available cash to cover this loan.',
                    style: TextStyle(color: AppColors.textMuted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.surfaceAlt),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Requested:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        Text(CurrencyFormatter.format(principal), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('Available:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        Text(CurrencyFormatter.format(availableToLoan), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.error)),
                        const SizedBox(height: 6),
                        Text('Fund Balance:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        Text(CurrencyFormatter.format(fundBalance), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please wait for more contributions to come in before re-applying.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            ),
          );
          return;
        }
      }

      final repo = ref.read(loanRequestRepositoryProvider);
      final approved = await repo.approveLoanRequest(loan.id!);
      ref.invalidate(pendingLoansProvider);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!context.mounted) return;
      if (approved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan request approved'), backgroundColor: Colors.green),
        );
        final receipts = await LoanReceiptRepository.getReceiptsByLoanId(loan.id!);
        final receipt = receipts.where((r) => r.copyFor == 'admin').firstOrNull
            ?? receipts.firstOrNull;
        if (receipt != null && context.mounted) {
          _showReceiptDialog(context, receipt);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan request already processed'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReceiptDialog(BuildContext context, LoanReceipt receipt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LendWUsLogo(fontSize: 18, showTagline: true),
                const SizedBox(height: 8),
                Text('Official Loan Receipt',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 1)),
                const SizedBox(height: 12),
                Container(height: 1, color: AppColors.surfaceAlt.withValues(alpha: 0.6)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('RECEIPT NO.', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)),
                    Text(receipt.receiptNumber,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withAlpha(50)),
                  ),
                  child: Column(
                    children: [
                      Text(CurrencyFormatter.format(receipt.totalAmountDue),
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      const SizedBox(height: 2),
                      Text('TOTAL AMOUNT DUE',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _receiptRow('Member', receipt.memberName, isStrong: true),
                _receiptRow('Principal', CurrencyFormatter.format(receipt.principal)),
                _receiptRow('Interest Rate', '${(receipt.interestRate * 100).toStringAsFixed(1)}%'),
                _receiptRow('Interest Amount', CurrencyFormatter.format(receipt.interestAmount)),
                Container(height: 1, color: AppColors.surfaceAlt.withValues(alpha: 0.6), margin: const EdgeInsets.symmetric(vertical: 10)),
                _receiptRow('Issue Date', DateFormatter.format(receipt.issuedDate)),
                _receiptRow('Due Date', DateFormatter.format(receipt.dueDate)),
                _receiptRow('Status', receipt.status.toUpperCase(),
                  valueColor: receipt.status == 'active' ? AppColors.warning : AppColors.success),
                _receiptRow('Generated', DateFormatter.format(receipt.generatedAt)),
                const SizedBox(height: 16),
                Container(height: 1, color: AppColors.surfaceAlt.withValues(alpha: 0.6)),
                const SizedBox(height: 12),
                Text('This is a computer-generated receipt. No signature required.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Thank you for being a part of LendWUs!',
                  style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _handleReject(BuildContext context) async {
    if (_busy) return;
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

    if (shouldReject != true) {
      notesController.dispose();
      return;
    }
    if (!mounted) {
      notesController.dispose();
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(loanRequestRepositoryProvider);
    final rejected = await repo.rejectLoanRequest(loan.id!, notes: notesController.text);
    notesController.dispose();

    ref.invalidate(pendingLoansProvider);

    if (!mounted) return;
    setState(() => _busy = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(rejected ? 'Loan request rejected' : 'Loan request already processed'),
          backgroundColor: rejected ? Colors.red : Colors.orange,
        ),
      );
    }
  }

  Widget _receiptRow(String label, String value, {bool isStrong = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const Spacer(),
          Text(value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13,
              fontWeight: isStrong ? FontWeight.w700 : FontWeight.w500,
            )),
        ],
      ),
    );
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

class _HeadChangeApprovalCard extends ConsumerStatefulWidget {
  final HeadChangeRequest request;

  const _HeadChangeApprovalCard({required this.request});

  @override
  ConsumerState<_HeadChangeApprovalCard> createState() => _HeadChangeApprovalCardState();
}

class _HeadChangeApprovalCardState extends ConsumerState<_HeadChangeApprovalCard> {
  bool _busy = false;

  HeadChangeRequest get request => widget.request;

  @override
  Widget build(BuildContext context) {
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
                    onPressed: _busy ? null : () => _handleReject(context),
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
                    onPressed: _busy ? null : () => _handleApprove(context),
                    icon: _busy
                        ? const SizedBox(
                            height: 14, width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
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
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Approve Head Change', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Approve head change from ${request.currentHeads} to ${request.requestedHeads} heads? This takes effect immediately.',
          style: TextStyle(color: AppColors.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);

    // Validate head change rules
    final now = DateTime.now();
    final isJanuary = now.month == 1;

    final contribSnapshot = await FirebaseService.firestore
        .collection('contributions')
        .where('memberId', isEqualTo: request.memberId)
        .get();

    final paymentSnapshot = await FirebaseService.firestore
        .collection('payment_requests')
        .where('memberId', isEqualTo: request.memberId)
        .get();

    final hasContributions = contribSnapshot.docs.isNotEmpty ||
        paymentSnapshot.docs.any((d) {
          final data = d.data();
          return data['status'] == 'approved' && data['type'] == 'contribution';
        });

    if (hasContributions && !isJanuary) {
      setState(() => _busy = false);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Cannot Approve', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'This member has existing contributions. Head changes are only allowed in January (start of the year reset).',
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
      return;
    }

    final repo = ref.read(headChangeRequestRepositoryProvider);
    final user = ref.read(currentUserProvider).state;
    final approved = await repo.approveHeadChangeRequest(
      request.id!,
      processedBy: user?.username ?? 'Admin',
    );

    ref.invalidate(pendingHeadChangesProvider);

    if (!mounted) return;
    setState(() => _busy = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Head change approved' : 'Head change already processed'),
          backgroundColor: approved ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _handleReject(BuildContext context) async {
    if (_busy) return;
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

    if (shouldReject != true) {
      notesController.dispose();
      return;
    }
    if (!mounted) {
      notesController.dispose();
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = ref.read(headChangeRequestRepositoryProvider);
      final user = ref.read(currentUserProvider).state;
      final rejected = await repo.rejectHeadChangeRequest(
        request.id!,
        processedBy: user?.username ?? 'Admin',
        notes: notesController.text,
      );

      ref.invalidate(pendingHeadChangesProvider);

      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rejected ? 'Head change rejected' : 'Head change already processed'),
            backgroundColor: rejected ? Colors.red : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting head change: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      notesController.dispose();
      if (mounted) setState(() => _busy = false);
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
