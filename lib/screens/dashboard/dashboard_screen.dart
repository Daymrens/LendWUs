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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
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
