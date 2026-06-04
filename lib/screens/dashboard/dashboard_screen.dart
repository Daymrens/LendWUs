import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/lendwus_logo.dart';
import '../../providers/fund_summary_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/returns_provider.dart';
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
            const LendWUsLogo(fontSize: 20),
            Text(
              'Family Circle · ${DateFormat('MMMM yyyy').format(DateTime.now())}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Admin Settings',
          ),
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
            _ReturnsSection(),
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

class _ReturnsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ReturnsSection> createState() => _ReturnsSectionState();
}

class _ReturnsSectionState extends ConsumerState<_ReturnsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(computeReturnsProvider.future);
    });
  }

  @override
  Widget build(BuildContext context) {
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
