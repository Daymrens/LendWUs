import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/returns_provider.dart';
import '../../data/models/contribution.dart';
import '../../data/models/member.dart';
import '../../data/models/loan_request.dart' show LoanRequestStatus;
import '../../data/models/payment_request.dart' show PaymentStatus, PaymentType;
import '../../data/models/app_settings.dart' show AppSettings;
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/payment_request_repository.dart';
import '../../data/repositories/loan_request_repository.dart';
import '../../providers/settings_provider.dart';
import '../../providers/members_provider.dart';
import '../modals/member_payment_modal.dart';
import '../modals/member_loan_request_modal.dart';
import '../modals/member_head_change_modal.dart';
import '../../providers/notification_provider.dart';

final memberContributionsStreamProvider = StreamProvider.family<List<Contribution>, String>((ref, memberId) {
  return ref.watch(contributionRepositoryProvider).watchMemberContributions(memberId);
});

final memberContributionsTotalProvider = FutureProvider.family<double, String>((ref, memberId) async {
  final contribs = [...?ref.watch(memberContributionsStreamProvider(memberId)).asData?.value];
  return contribs.fold<double>(0.0, (s, c) => s + c.amount);
});

final memberActiveLoansProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) {
  final repo = LoanRepository();
  return repo.watchMemberActiveLoans(memberId);
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
    final memberAsync = ref.watch(memberByIdProvider(memberId));
    final colorScheme = Theme.of(context).colorScheme;

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
                      context.push('/notifications');
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
            const SizedBox(height: 16),

            memberAsync.when(
              data: (member) => member != null ? _memberInfoCard(context, member, settingsAsync.valueOrNull) : const SizedBox(),
              loading: () => _shimmerCard(height: 80),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 16),

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
                  data: (total) => _statChip(context, 'My Contributions', total, AppColors.primary, isCurrency: true),
                  loading: () => _loadingChip(context),
                  error: (_, __) => _statChip(context, 'My Contributions', 0, AppColors.primary, isCurrency: true),
                ),
                const SizedBox(width: 8),
                memberLoansAsync.when(
                  data: (loans) => _statChip(context, 'Active Loans', loans.length, AppColors.warning),
                  loading: () => _loadingChip(context),
                  error: (_, __) => _statChip(context, 'Active Loans', 0, AppColors.warning),
                ),
                const SizedBox(width: 8),
                pendingCount.when(
                  data: (count) => _statChip(context, 'Pending', count, AppColors.secondary),
                  loading: () => _loadingChip(context),
                  error: (_, __) => _statChip(context, 'Pending', 0, AppColors.secondary),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _quickAction(context, Icons.add_circle, 'Pay Contribution', AppColors.primary, () {
                    final now = DateTime.now();
                    final allContribs = ref.read(memberContributionsStreamProvider(memberId)).asData?.value ?? [];
                    final thisMonth = allContribs.where((c) =>
                      c.date.month == now.month && c.date.year == now.year
                    ).toList();
                    final monthlyTotal = thisMonth.fold<double>(0.0, (s, c) => s + c.amount);
                    final member = ref.read(memberByIdProvider(memberId)).valueOrNull;
                    final perHeadAmount = member?.amountPerHead ?? 0;
                    final headCount = member?.headsCount ?? 1;
                    final perCutoffAmount = perHeadAmount * headCount;
                    final fullMonthlyRequired = perCutoffAmount * 2;

                    if (monthlyTotal >= perCutoffAmount && fullMonthlyRequired > 0) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(30),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.emoji_events, color: AppColors.primary, size: 28),
                              ),
                              const SizedBox(height: 16),
                              const Text("YOU'RE ON TRACK!",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'You\'ve met your contribution for this cutoff period.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Contributed: ${CurrencyFormatter.format(monthlyTotal)} / ${CurrencyFormatter.format(perCutoffAmount)} this cutoff',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Close'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        showModalBottomSheet(
                                          context: context, isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => const MemberPaymentModal(defaultAdvance: true),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Pay in Advance'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      showModalBottomSheet(
                        context: context, isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const MemberPaymentModal(),
                      );
                    }
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickAction(context, Icons.request_page, 'Request Loan', AppColors.warning, () {
                    showModalBottomSheet(
                      context: context, isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const MemberLoanRequestModal(),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickAction(context, Icons.people_alt, 'Change Heads', AppColors.secondary, () {
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

            _RecentContributions(memberId: memberId),

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
    final colorScheme = Theme.of(context).colorScheme;
    final contributionsAsync = ref.watch(memberContributionsStreamProvider(memberId));
    final memberAsync = ref.watch(memberByIdProvider(memberId));
    final memberContribs = contributionsAsync.asData?.value ?? [];
    final now = DateTime.now();
    final thisMonth = memberContribs.where((c) => c.date.month == now.month && c.date.year == now.year).toList();
    final monthlyTotal = thisMonth.fold<double>(0.0, (s, c) => s + c.amount);
    final member = memberAsync.asData?.value;
    final memberHeads = member?.headsCount ?? 1;
    final memberTotalRequired = (member?.totalRequired ?? 0.0) > 0
        ? member!.totalRequired
        : memberHeads * (settings?.minPaymentPerHead ?? 0.0);
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
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
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
            if (memberTotalRequired > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('This month: ${CurrencyFormatter.format(monthlyTotal)}',
                    style: TextStyle(color: monthlyTotal >= memberTotalRequired ? AppColors.primary : AppColors.warning, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('Required: ${CurrencyFormatter.format(memberTotalRequired)}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (monthlyTotal / memberTotalRequired).clamp(0.0, 1.0),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: monthlyTotal >= memberTotalRequired ? AppColors.primary : AppColors.warning,
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _memberInfoCard(BuildContext context, Member member, AppSettings? settings) {
    final colorScheme = Theme.of(context).colorScheme;
    final heads = member.headsCount;
    final perHead = settings?.minPaymentPerHead ?? 500.0;
    final totalRequired = member.totalRequired > 0 ? member.totalRequired : heads * perHead;
    final balance = member.balance ?? 0.0;
    final isActive = member.isActive;
    final displayName = member.name ?? 'Member';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withAlpha(25),
            child: Text(
              displayName[0].toUpperCase(),
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.success.withAlpha(25) : AppColors.warning.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: isActive ? AppColors.success : AppColors.warning,
                          fontSize: 10, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _infoChip(Icons.people_outline, '$heads head${heads > 1 ? 's' : ''}', AppColors.primary, colorScheme),
                    const SizedBox(width: 10),
                    _infoChip(Icons.monetization_on_outlined, '${CurrencyFormatter.currencySymbol}${CurrencyFormatter.format(perHead)}/head', AppColors.warning, colorScheme),
                    const SizedBox(width: 10),
                    _infoChip(Icons.assignment, 'Req: ${CurrencyFormatter.format(totalRequired)}', AppColors.secondary, colorScheme),
                  ],
                ),
                if (balance > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('Credit: ${CurrencyFormatter.format(balance)}',
                        style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _shimmerCard({double height = 120}) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(height > 80 ? 24 : 16),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _statChip(BuildContext context, String label, dynamic value, Color color, {bool isCurrency = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(isCurrency ? CurrencyFormatter.format((value as num).toDouble()) : '$value',
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _loadingChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    if (loans.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 40, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text('No active loans', style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
                        Text('Loan #${loan.id.length > 5 ? loan.id.substring(0, 5) : loan.id}',
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
                    Text('Due: ${loan.dueDate.day}/${loan.dueDate.month}/${loan.dueDate.year}',
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
        );
      }).toList(),
    );
  }
}

final _memberPendingRequestsProvider = FutureProvider.family<int, String>((ref, memberId) async {
  final paymentsRepo = PaymentRequestRepository();
  final loansRepo = LoanRequestRepository();
  final payments = await paymentsRepo.getPaymentRequestsByMember(memberId);
  final loans = await loansRepo.getLoanRequestsByMember(memberId);
  return payments.where((p) => p.status == PaymentStatus.pending).length +
         loans.where((l) => l.status == LoanRequestStatus.pending).length;
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

class _RecentContributions extends ConsumerWidget {
  final String memberId;

  const _RecentContributions({required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributionsAsync = ref.watch(memberContributionsStreamProvider(memberId));
    final contributions = [...?contributionsAsync.asData?.value];
    final sorted = List<Contribution>.from(contributions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = sorted.take(5).toList();

    if (recent.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Contributions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: recent.map((c) {
                final dateStr = _formatDate(c.date);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withAlpha(25),
                    child: const Icon(Icons.check, color: AppColors.primary, size: 16),
                  ),
                  title: Text(CurrencyFormatter.format(c.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: Text(dateStr,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(d);
  }
}
