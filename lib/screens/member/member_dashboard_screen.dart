import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/returns_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/loans_provider.dart';
import '../../data/models/app_settings.dart' show AppSettings;
import '../../data/models/payment_request.dart' show PaymentType;
import '../../providers/settings_provider.dart';
import '../modals/member_payment_modal.dart';
import '../modals/member_loan_request_modal.dart';
import '../modals/member_head_change_modal.dart';
import 'member_pay_screen.dart';
import '../../providers/notification_provider.dart';
import '../notifications/notifications_screen.dart';

final memberContributionsTotalProvider = FutureProvider.family<double, String>((ref, memberId) async {
  final contribs = [...?ref.watch(contributionsStreamProvider).asData?.value];
  return contribs.where((c) => c.memberId == memberId).fold<double>(0.0, (s, c) => s + c.amount);
});

final memberActiveLoansProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final loans = [...?ref.watch(loansStreamProvider).asData?.value];
  final repayments = [...?ref.watch(repaymentsStreamProvider).asData?.value];
  final active = loans.where((l) => l.memberId == memberId && !l.isFullyRepaid).toList();
  return active.map((l) {
    final loanRepayments = repayments.where((r) => r.loanId == l.id);
    final repaid = loanRepayments.fold<double>(0.0, (s, r) => s + r.amountPaid);
    final totalDue = l.principal + (l.principal * l.interestRate);
    return {'loan': l, 'remainingBalance': totalDue - repaid};
  }).toList();
});

class MemberDashboardScreen extends ConsumerWidget {
  const MemberDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(currentUserProvider);
    final user = auth.state;
    final memberId = user?.memberId;

    if (memberId == null) {
      return const Scaffold(body: Center(child: Text('Member ID not found')));
    }

    final memberContributionsAsync = ref.watch(memberContributionsTotalProvider(memberId));
    final memberLoansAsync = ref.watch(memberActiveLoansProvider(memberId));
    final pendingCount = ref.watch(_memberPendingRequestsProvider(memberId));
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final auth = ref.watch(currentUserProvider);
              final userId = auth.state?.id;
              final unread = userId != null
                  ? (ref.watch(unreadCountProvider(userId)).value ?? 0)
                  : 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ));
                    },
                    tooltip: 'Notifications',
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${user?.username}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            memberContributionsAsync.when(
              data: (total) => settingsAsync.when(
                data: (settings) => _buildContributionCard(context, ref, total, memberId, settings),
                loading: () => _buildContributionCard(context, ref, total, memberId, null),
                error: (_, __) => _buildContributionCard(context, ref, total, memberId, null),
              ),
              loading: () => _shimmerCard(),
              error: (_, __) => const Text('Error loading contributions'),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                memberContributionsAsync.when(
                  data: (total) => _statChip('My Contributions', total, AppColors.primary, isCurrency: true),
                  loading: () => _loadingChip(),
                  error: (_, __) => _statChip('My Contributions', 0, AppColors.primary, isCurrency: true),
                ),
                const SizedBox(width: 8),
                memberLoansAsync.when(
                  data: (loans) => _statChip('Active Loans', loans.length, AppColors.warning),
                  loading: () => _loadingChip(),
                  error: (_, __) => _statChip('Active Loans', 0, AppColors.warning),
                ),
                const SizedBox(width: 8),
                pendingCount.when(
                  data: (count) => _statChip('Pending', count, AppColors.secondary),
                  loading: () => _loadingChip(),
                  error: (_, __) => _statChip('Pending', 0, AppColors.secondary),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _quickAction(Icons.add_circle, 'Pay Contribution', AppColors.primary, () {
                    showModalBottomSheet(
                      context: context, isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const MemberPaymentModal(),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickAction(Icons.request_page, 'Request Loan', AppColors.warning, () {
                    showModalBottomSheet(
                      context: context, isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const MemberLoanRequestModal(),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickAction(Icons.people_alt, 'Change Heads', AppColors.secondary, () {
                    showModalBottomSheet(
                      context: context, isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const MemberHeadChangeModal(),
                    );
                  }),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text('My Active Loans',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            memberLoansAsync.when(
              data: (loans) => _buildLoansList(context, loans),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading loans'),
            ),

            const SizedBox(height: 24),
            _MemberReturnsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionCard(BuildContext context, WidgetRef ref, double total, String memberId, AppSettings? settings) {
    final contributionsAsync = ref.watch(contributionsStreamProvider);
    final allContribs = contributionsAsync.asData?.value ?? [];
    final memberContribs = allContribs.where((c) => c.memberId == memberId).toList();
    final now = DateTime.now();
    final thisMonth = memberContribs.where((c) => c.date.month == now.month && c.date.year == now.year).toList();
    final monthlyTotal = thisMonth.fold<double>(0.0, (s, c) => s + c.amount);
    final requiredPerHead = settings?.minPaymentPerHead ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Contributions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                  child: Text('${memberContribs.length} payments',
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(CurrencyFormatter.format(total),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            if (requiredPerHead > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('This month: ${CurrencyFormatter.format(monthlyTotal)}',
                    style: TextStyle(color: monthlyTotal >= requiredPerHead ? AppColors.primary : AppColors.warning, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('Required: ${CurrencyFormatter.format(requiredPerHead)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (monthlyTotal / requiredPerHead).clamp(0.0, 1.0),
                  backgroundColor: AppColors.surfaceAlt,
                  color: monthlyTotal >= requiredPerHead ? AppColors.primary : AppColors.warning,
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _shimmerCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _statChip(String label, dynamic value, Color color, {bool isCurrency = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(isCurrency ? CurrencyFormatter.format((value as num).toDouble()) : '$value',
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _loadingChip() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoansList(BuildContext context, List<Map<String, dynamic>> loans) {
    if (loans.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 40, color: AppColors.textMuted),
                SizedBox(height: 8),
                Text('No active loans', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: loans.map((loanData) {
        final loan = loanData['loan'];
        final remainingBalance = loanData['remainingBalance'] as double;
        final totalDue = loan.principal + (loan.principal * loan.interestRate);
        final progress = totalDue > 0 ? ((totalDue - remainingBalance) / totalDue).clamp(0.0, 1.0) : 0.0;
        final now = DateTime.now();
        final isOverdue = loan.dueDate.isBefore(now);
        final daysDiff = now.difference(loan.dueDate).inDays;

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
                        Text('Loan #${loan.id.substring(0, 5)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('${(loan.interestRate * 100).toStringAsFixed(0)}% interest',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(CurrencyFormatter.format(remainingBalance),
                          style: TextStyle(color: isOverdue ? AppColors.error : AppColors.warning, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(isOverdue ? '$daysDiff days overdue' : 'Balance due',
                          style: TextStyle(color: isOverdue ? AppColors.error : AppColors.textMuted, fontSize: 10)),
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
                        backgroundColor: AppColors.surfaceAlt,
                        color: isOverdue ? AppColors.error : AppColors.warning,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text('Principal: ${CurrencyFormatter.format(loan.principal)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                    Text('Due: ${loan.dueDate.day}/${loan.dueDate.month}/${loan.dueDate.year}',
                      style: TextStyle(color: isOverdue ? AppColors.error : AppColors.textMuted, fontSize: 12)),
                  ],
                ),
                const Divider(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MemberPayScreen(loanId: loan.id, paymentType: PaymentType.loan),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Repay Loan'),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

final _memberPendingRequestsProvider = FutureProvider.family<int, String>((ref, memberId) async {
  final payments = [...?ref.watch(pendingPaymentRequestsStreamProvider).asData?.value];
  final loans = [...?ref.watch(pendingLoanRequestsStreamProvider).asData?.value];
  return payments.where((p) => p.memberId == memberId).length +
         loans.where((l) => l.memberId == memberId).length;
});

class _MemberReturnsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(returnsInfoProvider);
    return returnsAsync.when(
      data: (info) {
        if (info.totalReturns <= 0 && info.totalHeads <= 0) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('End of Year Returns',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Returns Pool', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(CurrencyFormatter.format(info.totalReturns),
                            style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Per Head Share', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(CurrencyFormatter.format(info.perHeadShare),
                            style: const TextStyle(color: AppColors.secondary, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Heads', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('${info.totalHeads}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}
