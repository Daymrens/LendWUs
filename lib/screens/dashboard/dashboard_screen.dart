import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/lendwus_logo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fund_summary_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/loans_provider.dart';
import '../../providers/returns_provider.dart';
import 'widgets/stat_card.dart';
import 'widgets/action_buttons_row.dart';
import 'widgets/activity_chart.dart';
import 'widgets/recent_activity_list.dart';
import 'widgets/top_contributors.dart';
import '../modals/new_contribution_modal.dart';
import '../modals/issue_loan_modal.dart';
import '../modals/record_repayment_modal.dart';
import '../../providers/notification_provider.dart';
import '../../core/utils/member_id_generator.dart';
import '../../core/firebase/firebase_service.dart';
import 'widgets/donut_charts_row.dart';
import 'widgets/trends_bar_chart.dart';
import 'widgets/collection_rate_chart.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/loan_request.dart';
import '../../data/models/head_change_request.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _prevPendingCount = 0;
  bool _pendingModalInitialized = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(pendingApprovalsCountProvider, (prev, next) {
      if (!_pendingModalInitialized) {
        _prevPendingCount = next;
        _pendingModalInitialized = true;
        return;
      }
      if (next > _prevPendingCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showPendingRequestsDialog();
        });
      }
      _prevPendingCount = next;
    });

    final fundSummary = ref.watch(fundSummaryProvider);
    final members = ref.watch(membersStreamProvider);
    final pendingApprovals = ref.watch(pendingApprovalsCountProvider);
    final activeLoansCount = ref.watch(activeLoansCountProvider);
    final overdueLoansCount = ref.watch(overdueLoansCountProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LendWUsLogo(fontSize: 20),
            Text(
              DateFormat('MMMM yyyy').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Admin Settings',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.approval),
                onPressed: () => context.push('/approvals'),
                tooltip: 'Pending Approvals',
              ),
              if (pendingApprovals > 0)
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
                      pendingApprovals.toString(),
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
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fundSummary.when(
              data: (summary) => Column(
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                    children: [
                      StatCard(
                        title: 'Total Fund',
                        value: CurrencyFormatter.format(summary.fundBalance),
                        isGradient: true,
                        icon: Icons.account_balance,
                        iconColor: AppColors.primary,
                      ),
                      StatCard(
                        title: 'Total Members',
                        value: members.when(
                          data: (list) => list.length.toString(),
                          loading: () => '...',
                          error: (_, __) => '0',
                        ),
                        icon: Icons.people,
                        iconColor: AppColors.secondary,
                      ),
                      StatCard(
                        title: 'Active Loans',
                        value: activeLoansCount.toString(),
                        icon: Icons.account_balance_wallet,
                        iconColor: AppColors.warning,
                      ),
                      StatCard(
                        title: 'Interest Earned',
                        value: CurrencyFormatter.format(summary.totalInterestEarned),
                        icon: Icons.trending_up,
                        iconColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const Gap(12),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.0,
                    children: [
                      _miniStat(
                        'Total Loans',
                        CurrencyFormatter.format(summary.totalLoansIssued),
                        colorScheme.onSurfaceVariant,
                      ),
                      _miniStat(
                        'Overdue',
                        overdueLoansCount.toString(),
                        overdueLoansCount > 0 ? AppColors.warning : colorScheme.onSurfaceVariant,
                      ),
                      _miniStat(
                        'Pending',
                        pendingApprovals.toString(),
                        pendingApprovals > 0 ? AppColors.warning : colorScheme.onSurfaceVariant,
                      ),
                      _miniStat(
                        'Balance',
                        CurrencyFormatter.format(summary.fundBalance),
                        AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Error loading summary')),
            ),
            const Gap(24),
            ActionButtonsRow(
              onNewContribution: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const NewContributionModal(),
                );
              },
              onIssueLoan: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const IssueLoanModal(),
                );
              },
              onRecordRepayment: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const RecordRepaymentModal(),
                );
              },
              onBackfillIds: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Backfill Member IDs?'),
                    content: const Text(
                      'This will generate formatted IDs (LWS000000) for all members missing them, '
                      'ordered by their join date.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Backfill Now'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;

                try {
                  final count = await MemberIdGenerator.backfillMissingMemberIds(FirebaseService.firestore);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Backfilled $count members successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error backfilling: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              onViewMembers: () => context.push('/members'),
              onViewReports: () => context.push('/reports'),
              onViewApprovals: () => context.push('/approvals'),
            ),
            const Gap(24),
            _ReturnsSection(),
            const Gap(24),
            const TopContributors(),
            const Gap(24),
            const DonutChartsRow(),
            const Gap(24),
            const TrendsBarChart(),
            const Gap(24),
            const CollectionRateChart(),
            const Gap(24),
            Text(
              'Activity',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const Gap(16),
            const ActivityChart(),
            const Gap(16),
            const RecentActivityList(),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    final surfaceAlt = Theme.of(context).brightness == Brightness.dark
        ? AppColors.surfaceAlt
        : AppColors.lightSurfaceAlt;
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: textMuted,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showPendingRequestsDialog() async {
    final pendingPayments = [...?ref.read(pendingPaymentRequestsStreamProvider).value];
    final pendingLoans = [...?ref.read(pendingLoanRequestsStreamProvider).value];
    final pendingHeads = [...?ref.read(pendingHeadChangeRequestsStreamProvider).value];
    final members = [...?ref.read(membersStreamProvider).value];

    if (pendingPayments.isEmpty && pendingLoans.isEmpty && pendingHeads.isEmpty) return;

    final memberNameMap = {for (final m in members) m.id: m.name};

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(0),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: AppColors.warning, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'New Pending Requests',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pendingPayments.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              Text('PAYMENTS (${pendingPayments.length})', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warning, letterSpacing: 1)),
                            ],
                          ),
                        ),
                        ...pendingPayments.map((p) => _pendingRequestTile(
                          icon: p.type == PaymentType.loan ? Icons.credit_card : Icons.payments,
                          iconColor: p.type == PaymentType.loan ? AppColors.secondary : AppColors.primary,
                          memberName: memberNameMap[p.memberId] ?? p.memberId,
                          subtitle: p.type == PaymentType.loan ? 'Loan Repayment' : 'Contribution',
                          amount: CurrencyFormatter.format(p.amount),
                          amountColor: p.type == PaymentType.loan ? AppColors.secondary : AppColors.primary,
                        )),
                        const SizedBox(height: 8),
                      ],
                      if (pendingLoans.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              Text('LOAN REQUESTS (${pendingLoans.length})', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.secondary, letterSpacing: 1)),
                            ],
                          ),
                        ),
                        ...pendingLoans.map((l) => _pendingRequestTile(
                          icon: Icons.account_balance,
                          iconColor: AppColors.secondary,
                          memberName: l.memberName.isNotEmpty ? l.memberName : (memberNameMap[l.memberId] ?? l.memberId),
                          subtitle: 'Loan',
                          amount: CurrencyFormatter.format(l.amount),
                          amountColor: AppColors.secondary,
                        )),
                        const SizedBox(height: 8),
                      ],
                      if (pendingHeads.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              Text('HEAD CHANGES (${pendingHeads.length})', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.purple, letterSpacing: 1)),
                            ],
                          ),
                        ),
                        ...pendingHeads.map((h) => _pendingRequestTile(
                          icon: Icons.swap_horiz,
                          iconColor: Colors.purple,
                          memberName: h.memberName.isNotEmpty ? h.memberName : (memberNameMap[h.memberId] ?? h.memberId),
                          subtitle: '${h.currentHeads} → ${h.requestedHeads} heads',
                          amount: null,
                          amountColor: null,
                        )),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.surfaceAlt)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: BorderSide(color: AppColors.surfaceAlt),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/approvals');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Open Approvals', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingRequestTile({
    required IconData icon,
    required Color iconColor,
    required String memberName,
    required String subtitle,
    String? amount,
    Color? amountColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(memberName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 1),
                Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (amount != null)
            Text(amount, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: amountColor)),
        ],
      ),
    );
  }
}

class _ReturnsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(returnsInfoProvider);

    return returnsAsync.when(
      data: (info) {
        if (info.totalReturns <= 0 && info.totalHeads <= 0) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'End of Year Returns',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const Gap(12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Returns',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                          const Gap(4),
                          Text(
                            CurrencyFormatter.format(info.totalReturns),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Per Head Share',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                          const Gap(4),
                          Text(
                            CurrencyFormatter.format(info.perHeadShare),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Heads',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                          const Gap(4),
                          Text(
                            '${info.totalHeads}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
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
