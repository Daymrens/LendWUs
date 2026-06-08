import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/fund_provider.dart';
import '../../providers/loans_provider.dart';
import '../../providers/members_provider.dart';
import 'widgets/report_stat_card.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(totalFundProvider);
    ref.invalidate(totalLoansProvider);
    ref.invalidate(totalInterestProvider);
    ref.invalidate(membersStreamProvider);
    ref.invalidate(loansStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final totalContribution = ref.watch(totalFundProvider);
    final totalLoansIssued = ref.watch(totalLoansProvider);
    final totalInterest = ref.watch(totalInterestProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    final loansAsync = ref.watch(loansStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            membersAsync.when(
              data: (members) => loansAsync.when(
                data: (loans) {
                  final activeMembers = members.where((m) => m.isActive).length;
                  final activeLoans = loans.where((l) => !l.isFullyRepaid).length;
                  final completedLoans = loans.where((l) => l.isFullyRepaid).length;

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      ReportStatCard(
                        title: 'Total Contribution',
                        value: totalContribution.when(
                          data: (a) => CurrencyFormatter.format(a),
                          loading: () => '...',
                          error: (_, __) => '\$0',
                        ),
                        color: AppColors.primary,
                      ),
                      ReportStatCard(
                        title: 'Loans Issued',
                        value: totalLoansIssued.when(
                          data: (a) => CurrencyFormatter.format(a),
                          loading: () => '...',
                          error: (_, __) => '\$0',
                        ),
                        color: AppColors.secondary,
                      ),
                      ReportStatCard(
                        title: 'Interest Gained',
                        value: totalInterest.when(
                          data: (a) => CurrencyFormatter.format(a),
                          loading: () => '...',
                          error: (_, __) => '\$0',
                        ),
                        color: AppColors.warning,
                      ),
                      ReportStatCard(
                        title: 'Ending Balance',
                        value: totalContribution.when(
                          data: (contrib) => totalLoansIssued.when(
                            data: (loans) => CurrencyFormatter.format(contrib - loans),
                            loading: () => '...',
                            error: (_, __) => '\$0',
                          ),
                          loading: () => '...',
                          error: (_, __) => '\$0',
                        ),
                        color: AppColors.info,
                      ),
                      ReportStatCard(
                        title: 'Active Members',
                        value: '$activeMembers / ${members.length}',
                        color: AppColors.primary,
                      ),
                      ReportStatCard(
                        title: 'Loans Status',
                        value: '$activeLoans active · $completedLoans paid',
                        color: AppColors.secondary,
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const Gap(24),
            Text('Member Contributions', style: Theme.of(context).textTheme.displayMedium),
            const Gap(16),
            _buildContributionsByMember(ref),
            const Gap(24),
            Text('Loan Summary', style: Theme.of(context).textTheme.displayMedium),
            const Gap(16),
            _buildLoanSummary(ref),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildContributionsByMember(WidgetRef ref) {
    final contribsAsync = ref.watch(contributionsStreamProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    return contribsAsync.when(
      data: (contributions) {
        return membersAsync.when(
          data: (members) {
            final memberMap = {for (var m in members) m.id: m.name};
            Map<String, double> totals = {};
            for (var c in contributions) {
              totals.update(c.memberId, (v) => v + c.amount, ifAbsent: () => c.amount);
            }
            var sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            final grandTotal = contributions.fold<double>(0.0, (s, c) => s + c.amount);

            if (sorted.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                child: const Center(child: Text('No contributions yet', style: TextStyle(color: AppColors.textMuted))),
              );
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  const Row(
                    children: [
                      SizedBox(width: 28),
                      Gap(12),
                      Expanded(child: Text('Member', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                      Text('Total', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                      Gap(8),
                      SizedBox(width: 40, child: Text('%', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    ],
                  ),
                  const Divider(color: AppColors.surfaceAlt, height: 20),
                  ...sorted.map((e) {
                    final share = grandTotal > 0 ? (e.value / grandTotal * 100) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary.withAlpha(30),
                            child: Text((memberMap[e.key] ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const Gap(10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(memberMap[e.key] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: share / 100,
                                    backgroundColor: AppColors.surfaceAlt,
                                    color: AppColors.primary,
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(8),
                          Text(CurrencyFormatter.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const Gap(6),
                          SizedBox(width: 40, child: Text('${share.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.textMuted, fontSize: 11), textAlign: TextAlign.right)),
                        ],
                      ),
                    );
                  }),
                  const Divider(color: AppColors.surfaceAlt, height: 16),
                  Row(
                    children: [
                      const Spacer(),
                      Text('Total: ${CurrencyFormatter.format(grandTotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildLoanSummary(WidgetRef ref) {
    final loansAsync = ref.watch(loansStreamProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    final repaymentsAsync = ref.watch(repaymentsStreamProvider);
    return loansAsync.when(
      data: (loans) {
        return membersAsync.when(
          data: (members) {
            return repaymentsAsync.when(
              data: (repayments) {
                final memberMap = {for (var m in members) m.id: m.name};
                final activeLoans = loans.where((l) => !l.isFullyRepaid).toList();
                final paidLoans = loans.where((l) => l.isFullyRepaid).toList();

                if (loans.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('No loans yet', style: TextStyle(color: AppColors.textMuted))),
                  );
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('Active Loans (${activeLoans.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.warning)),
                              const Spacer(),
                              const Text('Due', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                          const Divider(color: AppColors.surfaceAlt, height: 16),
                          ...activeLoans.take(5).map((l) {
                            final loanRepayments = repayments.where((r) => r.loanId == l.id);
                            final repaid = loanRepayments.fold<double>(0.0, (s, r) => s + r.amountPaid);
                            final totalDue = l.principal + (l.principal * l.interestRate);
                            final isOverdue = l.dueDate.isBefore(DateTime.now());
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(memberMap[l.memberId] ?? 'Unknown',
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                  ),
                                  Text(CurrencyFormatter.format(totalDue - repaid),
                                    style: TextStyle(color: isOverdue ? AppColors.warning : AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12)),
                                  const Gap(8),
                                  Text('${l.dueDate.day}/${l.dueDate.month}',
                                    style: TextStyle(color: isOverdue ? AppColors.warning : AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const Gap(12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('Paid Loans (${paidLoans.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                              const Spacer(),
                              const Text('Interest', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                          const Divider(color: AppColors.surfaceAlt, height: 16),
                          ...paidLoans.take(5).map((l) {
                            final loanRepayments = repayments.where((r) => r.loanId == l.id);
                            final repaid = loanRepayments.fold<double>(0.0, (s, r) => s + r.amountPaid);
                            final interest = repaid - l.principal;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(memberMap[l.memberId] ?? 'Unknown',
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                  ),
                                  Text(CurrencyFormatter.format(repaid),
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                                  const Gap(8),
                                  Text('+${CurrencyFormatter.format(interest)}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            );
          },
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}
