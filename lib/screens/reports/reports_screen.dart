import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/contribution.dart';
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
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.month == now.month && _selectedMonth.year == now.year;
  }

  Future<void> _refresh() async {
    ref.invalidate(totalContributionsProvider);
    ref.invalidate(totalLoansProvider);
    ref.invalidate(totalInterestProvider);
    ref.invalidate(totalRepaymentsProvider);
    ref.invalidate(membersStreamProvider);
    ref.invalidate(loansStreamProvider);
    ref.invalidate(contributionsStreamProvider);
    ref.invalidate(repaymentsStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final totalContribution = ref.watch(totalContributionsProvider);
    final totalLoansIssued = ref.watch(totalLoansProvider);
    final totalInterest = ref.watch(totalInterestProvider);
    final totalRepayments = ref.watch(totalRepaymentsProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    final loansAsync = ref.watch(loansStreamProvider);
    final contributionsAsync = ref.watch(contributionsStreamProvider);
    final repaymentsAsync = ref.watch(repaymentsStreamProvider);

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
            // Month navigation
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousMonth,
                  ),
                  const Gap(8),
                  Text(
                    '${_monthName(_selectedMonth.month)} ${_selectedMonth.year}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Gap(8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _isCurrentMonth ? null : _nextMonth,
                  ),
                ],
              ),
            ),
            const Gap(16),
            membersAsync.when(
              data: (members) => loansAsync.when(
                data: (loans) => contributionsAsync.when(
                  data: (contributions) => repaymentsAsync.when(
                    data: (repayments) {
                      // Compute month-scoped values
                      final monthContribs = contributions.where((c) =>
                          c.date.month == _selectedMonth.month && c.date.year == _selectedMonth.year);
                      final monthLoans = loans.where((l) =>
                          l.issuedDate.month == _selectedMonth.month && l.issuedDate.year == _selectedMonth.year);
                      final monthRepays = repayments.where((r) =>
                          r.date.month == _selectedMonth.month && r.date.year == _selectedMonth.year);

                      final monthContribTotal = monthContribs.fold<double>(0.0, (s, c) => s + c.amount);
                      final monthLoanTotal = monthLoans.fold<double>(0.0, (s, l) => s + l.principal);

                      double monthInterest = 0.0;
                      for (final r in monthRepays) {
                        final loan = loans.where((l) => l.id == r.loanId).firstOrNull;
                        if (loan != null) {
                          final allRepayments = repayments.where((r2) => r2.loanId == loan.id);
                          final totalRepaid = allRepayments.fold<double>(0.0, (s, r2) => s + r2.amountPaid);
                          final excess = totalRepaid - loan.principal;
                          if (excess > 0) {
                            // Only count interest from this month's repayments
                            final beforeMonthRepaid = repayments
                                .where((r2) => r2.loanId == loan.id &&
                                    (r2.date.year < _selectedMonth.year ||
                                     (r2.date.year == _selectedMonth.year && r2.date.month < _selectedMonth.month)))
                                .fold<double>(0.0, (s, r2) => s + r2.amountPaid);
                            final beforeExcess = beforeMonthRepaid - loan.principal;
                            monthInterest += excess - (beforeExcess > 0 ? beforeExcess : 0);
                          }
                        }
                      }
                      if (monthInterest < 0) monthInterest = 0;

                      final monthEndingBalance = monthContribTotal - monthLoanTotal + monthRepays.fold<double>(0.0, (s, r) => s + r.amountPaid);

                      final activeMembers = members.where((m) => m.isActive).length;
                      final activeLoans = loans.where((l) => !l.isFullyRepaid).length;
                      final completedLoans = loans.where((l) => l.isFullyRepaid).length;

                      return Column(
                        children: [
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.5,
                            children: [
                              ReportStatCard(
                                title: 'Total Contribution',
                                value: CurrencyFormatter.format(monthContribTotal),
                                color: AppColors.primary,
                              ),
                              ReportStatCard(
                                title: 'Loans Issued',
                                value: CurrencyFormatter.format(monthLoanTotal),
                                color: AppColors.secondary,
                              ),
                              ReportStatCard(
                                title: 'Interest Gained',
                                value: CurrencyFormatter.format(monthInterest),
                                color: AppColors.warning,
                              ),
                              ReportStatCard(
                                title: 'Ending Balance',
                                value: CurrencyFormatter.format(monthEndingBalance),
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
                          ),
                          const Gap(24),
                          Text('Member Contributions', style: Theme.of(context).textTheme.displayMedium),
                          const Gap(16),
                          _buildContributionsByMember(ref, contributions),
                          const Gap(24),
                          Text('Loan Summary', style: Theme.of(context).textTheme.displayMedium),
                          const Gap(16),
                          _buildLoanSummary(ref),
                        ],
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _monthName(int month) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month - 1];
  }

  Widget _buildContributionsByMember(WidgetRef ref, List<Contribution> allContributions) {
    final membersAsync = ref.watch(membersStreamProvider);
    final contributions = allContributions
        .where((c) => c.date.month == _selectedMonth.month && c.date.year == _selectedMonth.year)
        .toList();
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
                child: Center(child: Text('No contributions yet', style: TextStyle(color: AppColors.textMuted))),
              );
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 28),
                      Gap(12),
                      Expanded(child: Text('Member', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                      Text('Total', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                      Gap(8),
                      SizedBox(width: 40, child: Text('%', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    ],
                  ),
                  Divider(color: AppColors.surfaceAlt, height: 20),
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
                          SizedBox(width: 40, child: Text('${share.toStringAsFixed(1)}%', style: TextStyle(color: AppColors.textMuted, fontSize: 11), textAlign: TextAlign.right)),
                        ],
                      ),
                    );
                  }),
                  Divider(color: AppColors.surfaceAlt, height: 16),
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
                    child: Center(child: Text('No loans yet', style: TextStyle(color: AppColors.textMuted))),
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
                              Text('Due', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                          Divider(color: AppColors.surfaceAlt, height: 16),
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
                              Text('Interest', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                          Divider(color: AppColors.surfaceAlt, height: 16),
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
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
