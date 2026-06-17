import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/services/security_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/returns_provider.dart';
import '../../data/models/contribution.dart';
import '../../data/models/member.dart';
import '../../data/models/loan.dart';
import '../../data/models/payment_request.dart' show PaymentRequest, PaymentStatus, PaymentType;
import '../../data/models/loan_request.dart' show LoanRequest, LoanRequestStatus;
import '../../data/models/app_settings.dart' show AppSettings;
import '../../data/repositories/loan_repository.dart';
import '../../providers/settings_provider.dart';
import '../../providers/members_provider.dart';
import '../modals/member_payment_modal.dart';
import '../modals/member_loan_request_modal.dart';
import '../modals/member_head_change_modal.dart';
import '../../providers/notification_provider.dart';
import '../../data/repositories/notification_repository.dart';
import '../dashboard/widgets/popup_overlay.dart';

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

    return _BiometricPromptGate(
      child: PopupOverlay(
        child: Scaffold(
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
                        if (userId != null) {
                          _showNotificationSheet(context, ref, userId);
                        }
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
                _statChip(context, 'Pending', pendingCount, AppColors.secondary),
              ],
            ),

            const SizedBox(height: 20),

            _QuickActionsRow(memberId: memberId, activeLoansAsync: memberLoansAsync),

            const SizedBox(height: 24),

            _RecentContributions(memberId: memberId),

            const SizedBox(height: 24),

            if (memberLoansAsync.hasValue) ...[
              Text('My Active Loans',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              memberLoansAsync.when(
                data: (loans) => _buildLoansList(context, loans),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading loans'),
              ),
            ],

            const SizedBox(height: 24),
            _MemberReturnsSection(),
          ],
        ),
      ),
    ),
  ));
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
    final memberTotalRequired = member?.totalRequired ?? 0.0;
    final computedRequired = memberTotalRequired > 0
        ? memberTotalRequired
        : memberHeads * (member?.amountPerHead ?? 0.0);
    final progress = computedRequired > 0 ? (monthlyTotal / computedRequired).clamp(0.0, 1.0) : 0.0;
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
            if (computedRequired > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('This month: ${CurrencyFormatter.format(monthlyTotal)}',
                    style: TextStyle(color: monthlyTotal >= computedRequired ? AppColors.primary : AppColors.warning, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('Required: ${CurrencyFormatter.format(computedRequired)}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: monthlyTotal >= computedRequired ? AppColors.primary : AppColors.warning,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: _statusBadge(monthlyTotal, computedRequired),
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
    final perHead = member.amountPerHead ?? 500.0;
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
                    _infoChip(Icons.monetization_on_outlined, '${CurrencyFormatter.format(perHead)}/head', AppColors.warning, colorScheme),
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

  Widget _statusBadge(double paid, double required) {
    if (paid >= required) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Paid',
          style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
      );
    }
    if (paid <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Pending',
          style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
      );
    }
    final pct = (paid / required * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$pct%',
        style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w600)),
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
        final loan = loanData['loan'] as Loan?;
        if (loan == null) return const SizedBox();
        final remainingBalance = (loanData['remainingBalance'] as num?)?.toDouble() ?? 0.0;
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

final _memberPaymentRequestsStreamProvider = StreamProvider.family<List<PaymentRequest>, String>((ref, memberId) {
  return ref.watch(paymentRequestRepositoryProvider).watchMemberPaymentRequests(memberId);
});

final _memberLoanRequestsStreamProvider = StreamProvider.family<List<LoanRequest>, String>((ref, memberId) {
  return ref.watch(loanRequestRepositoryProvider).watchMemberLoanRequests(memberId);
});

final _memberPendingRequestsProvider = Provider.family<int, String>((ref, memberId) {
  final payments = [...?ref.watch(_memberPaymentRequestsStreamProvider(memberId)).asData?.value];
  final loans = [...?ref.watch(_memberLoanRequestsStreamProvider(memberId)).asData?.value];
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
                          Text('Returns Pool', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                          Text('Per Head Share', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                          Text('Heads', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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

void showPayContributionSheet(BuildContext context, WidgetRef ref, String memberId) {
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
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
}

void showLoanRequestSheet(BuildContext context) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const MemberLoanRequestModal(),
  );
}

void showHeadChangeSheet(BuildContext context) {
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const MemberHeadChangeModal(),
  );
}

Widget _enhancedQuickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickActionsRow extends ConsumerWidget {
  final String memberId;
  final AsyncValue<List<Map<String, dynamic>>> activeLoansAsync;

  const _QuickActionsRow({required this.memberId, required this.activeLoansAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLoans = activeLoansAsync.asData?.value ?? [];
    final hasActiveLoans = activeLoans.any((l) {
      final loan = l['loan'] as Loan?;
      return loan != null && !loan.isFullyRepaid;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = hasActiveLoans
                ? (constraints.maxWidth - 24) / 4
                : (constraints.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _enhancedQuickAction(context, Icons.wallet, 'Pay', AppColors.primary,
                    () => showPayContributionSheet(context, ref, memberId)),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _enhancedQuickAction(context, Icons.add_chart, 'Loan', AppColors.warning,
                    () => showLoanRequestSheet(context)),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _enhancedQuickAction(context, Icons.people_alt, 'Heads', AppColors.secondary,
                    () => showHeadChangeSheet(context)),
                ),
                if (hasActiveLoans)
                  SizedBox(
                    width: itemWidth,
                    child: _enhancedQuickAction(context, Icons.payments, 'Repay', Colors.pink, () {
                      context.push('/member-pay');
                    }),
                  ),
              ],
            );
          },
        ),
      ],
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
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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

void _showNotificationSheet(BuildContext context, WidgetRef ref, String userId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      expand: false,
      builder: (scrollCtx, scrollController) => Consumer(
        builder: (context, ref, _) {
          final notificationsAsync = ref.watch(notificationStreamProvider(userId));
          final unreadCount = ref.watch(unreadCountProvider(userId)).value ?? 0;

          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Notifications',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (unreadCount > 0)
                        Text('$unreadCount unread',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: notificationsAsync.when(
                    data: (notifications) {
                      if (notifications.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off, size: 48,
                                color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text('No notifications',
                                style: TextStyle(color: AppColors.textMuted)),
                            ],
                          ),
                        );
                      }
                      final recent = notifications.take(10).toList();
                      return ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: recent.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 20),
                        itemBuilder: (_, index) {
                          final n = recent[index];
                          return ListTile(
                            leading: Icon(
                              _iconForNotifType(n.type),
                              color: n.read
                                  ? AppColors.textMuted
                                  : AppColors.primary,
                              size: 22,
                            ),
                            title: Text(n.title,
                              style: TextStyle(
                                fontWeight: n.read
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 14,
                              )),
                            subtitle: Text(n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: n.read ? AppColors.textMuted : null,
                              )),
                            tileColor: n.read ? null : AppColors.surfaceAlt,
                            onTap: () {
                              if (!n.read && n.id != null) {
                                NotificationRepository().markAsRead(n.id!);
                              }
                            },
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

IconData _iconForNotifType(String type) {
  switch (type) {
    case 'payment':
      return Icons.payment;
    case 'loan':
      return Icons.account_balance;
    case 'approval':
      return Icons.check_circle;
    case 'head_change':
      return Icons.people_alt;
    case 'reminder':
      return Icons.notifications_active;
    case 'all_paid':
      return Icons.celebration;
    case 'system':
      return Icons.info;
    default:
      return Icons.notifications;
  }
}

class _BiometricPromptGate extends StatefulWidget {
  final Widget child;
  const _BiometricPromptGate({required this.child});

  @override
  State<_BiometricPromptGate> createState() => _BiometricPromptGateState();
}

class _BiometricPromptGateState extends State<_BiometricPromptGate> {
  @override
  void initState() {
    super.initState();
    _checkBiometricEnrollment();
  }

  Future<void> _checkBiometricEnrollment() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final available = await SecurityService.isBiometricAvailable();
      if (!available || !mounted) return;
      final enabled = await SecurityService.isBiometricEnabled();
      if (enabled || !mounted) return;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Fingerprint Sign-In?'),
          content: const Text('Would you like to sign in with your fingerprint next time?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Skip')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
          ],
        ),
      );

      if (result == true && mounted) {
        await SecurityService.enableBiometricAuth();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}


