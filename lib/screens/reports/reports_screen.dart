import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/fund_provider.dart';
import '../../providers/loans_provider.dart';
import 'widgets/report_stat_card.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalContribution = ref.watch(totalFundProvider);
    final totalLoans = ref.watch(totalLoansProvider);
    final totalInterest = ref.watch(totalInterestProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {},
            ),
            const Text('June 2026'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {},
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  value: totalContribution.when(
                    data: (amount) => CurrencyFormatter.format(amount),
                    loading: () => '...',
                    error: (_, __) => '\$0',
                  ),
                  color: AppColors.primary,
                ),
                ReportStatCard(
                  title: 'Loans Issued',
                  value: totalLoans.when(
                    data: (amount) => CurrencyFormatter.format(amount),
                    loading: () => '...',
                    error: (_, __) => '\$0',
                  ),
                  color: AppColors.primary,
                ),
                ReportStatCard(
                  title: 'Interest Gained',
                  value: totalInterest.when(
                    data: (amount) => CurrencyFormatter.format(amount),
                    loading: () => '...',
                    error: (_, __) => '\$0',
                  ),
                  color: AppColors.secondary,
                ),
                ReportStatCard(
                  title: 'Ending Balance',
                  value: totalContribution.when(
                    data: (contrib) => totalLoans.when(
                      data: (loans) => CurrencyFormatter.format(contrib - loans),
                      loading: () => '...',
                      error: (_, __) => '\$0',
                    ),
                    loading: () => '...',
                    error: (_, __) => '\$0',
                  ),
                  color: AppColors.secondary,
                ),
              ],
            ),
            const Gap(24),
            Text(
              'Member Contributions',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const Gap(16),
            FutureBuilder(
              future: ref.read(fundRepositoryProvider).getAllContributions(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final contributions = snapshot.data!;

                if (contributions.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'No contributions yet',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: contributions.map((contrib) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Contribution'),
                                Text(
                                  '${contrib.date.day}/${contrib.date.month}/${contrib.date.year}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            Text(
                              CurrencyFormatter.format(contrib.amount),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
