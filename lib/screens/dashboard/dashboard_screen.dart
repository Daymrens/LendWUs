import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/fund_summary_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/auth_provider.dart';
import 'widgets/stat_card.dart';
import 'widgets/action_buttons_row.dart';
import 'widgets/activity_chart.dart';
import 'widgets/recent_activity_list.dart';
import '../modals/new_contribution_modal.dart';
import '../modals/issue_loan_modal.dart';
import '../modals/record_repayment_modal.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundSummary = ref.watch(fundSummaryProvider);
    final members = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sinking Fund'),
            Text(
              'Family Circle · June 2026',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.approval),
            onPressed: () => context.push('/approvals'),
            tooltip: 'Pending Approvals',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(fundSummaryProvider);
              ref.invalidate(membersProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(currentUserProvider).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fundSummary.when(
              data: (summary) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  StatCard(
                    title: 'Total Fund',
                    value: CurrencyFormatter.format(summary.fundBalance),
                    isGradient: true,
                  ),
                  StatCard(
                    title: 'Total Members',
                    value: members.when(
                      data: (list) => list.length.toString(),
                      loading: () => '...',
                      error: (_, __) => '0',
                    ),
                  ),
                  StatCard(
                    title: 'Total Loans',
                    value: CurrencyFormatter.format(summary.totalLoansIssued),
                  ),
                  StatCard(
                    title: 'Interest Earned',
                    value: CurrencyFormatter.format(summary.totalInterestEarned),
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
            ),
            const Gap(24),
            Text(
              'Recent Activity',
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
}
