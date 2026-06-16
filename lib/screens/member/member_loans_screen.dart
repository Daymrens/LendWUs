import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/lendwus_logo.dart';
import '../../data/models/loan.dart';
import '../../data/models/repayment.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/loan_receipt_repository.dart';
import '../../data/models/payment_request.dart' show PaymentType;
import '../../providers/auth_provider.dart';

final memberLoansProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) {
  final repo = LoanRepository();
  return repo.watchMemberActiveLoans(memberId);
});

final memberAllLoansProvider = StreamProvider.family<List<Loan>, String>((ref, memberId) {
  final repo = LoanRepository();
  return repo.watchLoansByMember(memberId);
});

final _shownReceiptLoanIds = <String>{};

class MemberLoansScreen extends ConsumerStatefulWidget {
  const MemberLoansScreen({super.key});

  @override
  ConsumerState<MemberLoansScreen> createState() => _MemberLoansScreenState();
}

class _MemberLoansScreenState extends ConsumerState<MemberLoansScreen> {
  String? _memberId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupReceiptListener());
  }

  void _setupReceiptListener() {
    final auth = ref.read(currentUserProvider);
    final uid = auth.state?.memberId;
    if (uid == null) return;
    _memberId = uid;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(currentUserProvider);
    final user = auth.state;
    final memberId = user?.memberId ?? _memberId;
    final colorScheme = Theme.of(context).colorScheme;

    if (memberId == null) {
      return const Scaffold(body: Center(child: Text('Member ID not found')));
    }

    final activeLoansAsync = ref.watch(memberLoansProvider(memberId));

    // Auto-pop receipt for newly approved loans
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(memberLoansProvider(memberId), (previous, next) {
      previous?.whenData((prevData) {
        next.whenData((currData) {
          if (currData.isEmpty) return;
          final prevIds = prevData.map((m) => (m['loan'] as Loan?)?.id).whereType<String>().toSet();
          for (final curr in currData) {
            final loan = curr['loan'] as Loan?;
            final id = loan?.id;
            if (id != null && !prevIds.contains(id) && _shownReceiptLoanIds.add(id)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) _showReceiptDialog(context, id);
              });
            }
          }
        });
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Loans'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(memberLoansProvider(memberId));
          ref.invalidate(memberAllLoansProvider(memberId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Loans',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              activeLoansAsync.when(
                data: (loans) => loans.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.check_circle, size: 48, color: AppColors.success),
                                const SizedBox(height: 12),
                                Text('No active loans',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('You have no outstanding loans.',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: loans.map((loanData) {
                          final loan = loanData['loan'] as Loan?;
                          if (loan == null) return const SizedBox();
                          final remainingBalance = (loanData['remainingBalance'] as num?)?.toDouble() ?? 0.0;
                          final totalDue = loan.principal + (loan.principal * loan.interestRate);
                          final progress = totalDue > 0 ? ((totalDue - remainingBalance) / totalDue).clamp(0.0, 1.0) : 0.0;
                          final now = DateTime.now();
                          final isOverdue = loan.dueDate.isBefore(now);
                          final daysDiff = now.difference(loan.dueDate).inDays;

                          return GestureDetector(
                            onTap: () => _showLoanDetailSheet(context, loan, remainingBalance, progress, totalDue, isOverdue, daysDiff),
                            child: Card(
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
                                          Text('Loan #${loan.id != null && loan.id!.length > 5 ? loan.id!.substring(0, 5) : (loan.id ?? '')}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          Text('${(loan.interestRate * 100).toStringAsFixed(0)}% interest',
                                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(CurrencyFormatter.format(remainingBalance),
                                            style: TextStyle(color: isOverdue ? AppColors.error : AppColors.warning, fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text(isOverdue ? '$daysDiff days overdue' : 'Balance due',
                                            style: TextStyle(color: isOverdue ? AppColors.error : colorScheme.onSurfaceVariant, fontSize: 10)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: colorScheme.surfaceContainerHighest,
                                          color: isOverdue ? AppColors.error : AppColors.warning,
                                          minHeight: 6,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${(progress * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('Principal: ${CurrencyFormatter.format(loan.principal)}',
                                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                                      ),
                                      Text('Due: ${DateFormat('M/d/yyyy').format(loan.dueDate)}',
                                        style: TextStyle(color: isOverdue ? AppColors.error : colorScheme.onSurfaceVariant, fontSize: 12)),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        context.push('/member-pay', extra: {
                                          'loanId': loan.id,
                                          'paymentType': PaymentType.loan.name,
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.warning, foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Repay Loan'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ),
                          );
                        }).toList(),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, size: 40, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('Error loading loans', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _RepaidLoansSection(memberId: memberId),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepaidLoansSection extends ConsumerWidget {
  final String memberId;
  const _RepaidLoansSection({required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLoansAsync = ref.watch(memberAllLoansProvider(memberId));
    final colorScheme = Theme.of(context).colorScheme;

    return allLoansAsync.when(
      data: (loans) {
        final repaid = loans.where((l) => l.isFullyRepaid).toList();
        if (repaid.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repaid Loans',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...repaid.map((loan) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.success,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
                title: Text('Loan #${loan.id != null && loan.id!.length > 5 ? loan.id!.substring(0, 5) : (loan.id ?? '')}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Principal: ${CurrencyFormatter.format(loan.principal)} • ${(loan.interestRate * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Paid',
                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
            )),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

void _showLoanDetailSheet(BuildContext context, Loan loan, double remainingBalance, double progress, double totalDue, bool isOverdue, int daysDiff) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ActiveLoanDetailSheet(
      loan: loan,
      remainingBalance: remainingBalance,
      progress: progress,
      totalDue: totalDue,
      isOverdue: isOverdue,
      daysDiff: daysDiff,
    ),
  );
}

Future<void> _showReceiptDialog(BuildContext context, String loanId) async {
  try {
    final receipts = await LoanReceiptRepository.getReceiptsByLoanId(loanId);
    final receipt = receipts.where((r) => r.copyFor == 'borrower').firstOrNull
        ?? receipts.firstOrNull;
    if (receipt == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No receipt found. Ask an admin to generate one.')),
        );
      }
      return;
    }

    if (context.mounted) {
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
                  // Receipt number
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('RECEIPT NO.', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)),
                      Text(receipt.receiptNumber,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Amount
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
                  // Details
                  _receiptRow('Borrower', receipt.memberName, isStrong: true),
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
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load receipt: $e')),
      );
    }
  }
}

class _ActiveLoanDetailSheet extends ConsumerStatefulWidget {
  final Loan loan;
  final double remainingBalance;
  final double progress;
  final double totalDue;
  final bool isOverdue;
  final int daysDiff;

  const _ActiveLoanDetailSheet({
    required this.loan,
    required this.remainingBalance,
    required this.progress,
    required this.totalDue,
    required this.isOverdue,
    required this.daysDiff,
  });

  @override
  ConsumerState<_ActiveLoanDetailSheet> createState() => _ActiveLoanDetailSheetState();
}

class _ActiveLoanDetailSheetState extends ConsumerState<_ActiveLoanDetailSheet> {
  List<Repayment>? _repayments;
  bool _loadingRepayments = true;

  @override
  void initState() {
    super.initState();
    _fetchRepayments();
  }

  Future<void> _fetchRepayments() async {
    final repo = LoanRepository();
    final loanId = widget.loan.id;
    if (loanId == null) {
      if (mounted) setState(() => _loadingRepayments = false);
      return;
    }
    try {
      final repayments = await repo.getRepaymentsByLoan(loanId);
      if (mounted) {
        setState(() {
          _repayments = repayments;
          _loadingRepayments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRepayments = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.loan;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Icon(
                  widget.isOverdue ? Icons.warning_amber_rounded : Icons.account_balance,
                  size: 40, color: widget.isOverdue ? AppColors.error : AppColors.warning,
                ),
                const SizedBox(height: 8),
                Text(
                  'Loan #${l.id != null && l.id!.length > 5 ? l.id!.substring(0, 5) : (l.id ?? '')}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(widget.remainingBalance),
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                    color: widget.isOverdue ? AppColors.error : Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isOverdue ? '${widget.daysDiff} days overdue' : 'Remaining Balance',
                  style: TextStyle(color: widget.isOverdue ? AppColors.error : AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: widget.progress,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: widget.isOverdue ? AppColors.error : AppColors.warning,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(widget.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          _detailRow('Principal', CurrencyFormatter.format(l.principal)),
          _detailRow('Interest Rate', '${(l.interestRate * 100).toStringAsFixed(0)}%'),
          _detailRow('Total Due', CurrencyFormatter.format(widget.totalDue)),
          _detailRow('Paid So Far', CurrencyFormatter.format(widget.totalDue - widget.remainingBalance)),
          _detailRow('Remaining', CurrencyFormatter.format(widget.remainingBalance)),
          _detailRow('Issued', DateFormatter.format(l.issuedDate)),
          _detailRow('Due Date', DateFormatter.format(l.dueDate)),
          if (l.isFullyRepaid)
            _detailRow('Status', 'Paid'),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.surfaceAlt),
          const SizedBox(height: 12),
          Text('REPAYMENT HISTORY',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 8),
          if (_loadingRepayments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_repayments == null || _repayments!.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No repayments recorded', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            )
          else
            ..._repayments!.map((r) => Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.surfaceAlt.withAlpha(100))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(CurrencyFormatter.format(r.amountPaid),
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                      Text(DateFormatter.format(r.date),
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                ],
              ),
            )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showReceiptDialog(context, l.id!),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('View Receipt'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withAlpha(80)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
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