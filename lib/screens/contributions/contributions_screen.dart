import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/contribution.dart';
import '../../data/models/member.dart';
import '../../providers/fund_provider.dart';
import '../../providers/members_provider.dart';
import '../modals/new_contribution_modal.dart';

class ContributionsScreen extends ConsumerWidget {
  const ContributionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contributions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCards(ref),
            const Gap(24),
            Text(
              'Monthly Trend',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const Gap(16),
            _buildMonthlyChart(ref),
            const Gap(24),
            Text(
              'Top Contributors',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const Gap(16),
            _buildTopContributors(ref),
            const Gap(24),
            Text(
              'Recent Contributions',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const Gap(16),
            _buildRecentContributions(ref),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const NewContributionModal(),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Contribution'),
      ),
    );
  }

  Widget _buildStatCards(WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(fundRepositoryProvider).getAllContributions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final contributions = snapshot.data!;
        final now = DateTime.now();
        
        final thisMonth = contributions.where((c) => 
          c.date.month == now.month && c.date.year == now.year
        );
        
        final lastMonth = contributions.where((c) {
          final lastMonthDate = DateTime(now.year, now.month - 1);
          return c.date.month == lastMonthDate.month && c.date.year == lastMonthDate.year;
        });

        final totalThisMonth = thisMonth.fold<double>(0.0, (sum, c) => sum + c.amount);
        final totalLastMonth = lastMonth.fold<double>(0.0, (sum, c) => sum + c.amount);
        final totalAll = contributions.fold<double>(0.0, (sum, c) => sum + c.amount);
        
        final percentChange = totalLastMonth > 0 
          ? ((totalThisMonth - totalLastMonth) / totalLastMonth * 100)
          : 0.0;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard(
              'This Month',
              CurrencyFormatter.format(totalThisMonth),
              percentChange >= 0 ? '+${percentChange.toStringAsFixed(1)}%' : '${percentChange.toStringAsFixed(1)}%',
              percentChange >= 0 ? AppColors.primary : AppColors.warning,
            ),
            _buildStatCard(
              'Total Contributions',
              CurrencyFormatter.format(totalAll),
              '${contributions.length} transactions',
              AppColors.secondary,
            ),
            _buildStatCard(
              'Last Month',
              CurrencyFormatter.format(totalLastMonth),
              '${lastMonth.length} transactions',
              AppColors.surfaceAlt,
            ),
            _buildStatCard(
              'Average',
              CurrencyFormatter.format(contributions.isEmpty ? 0 : totalAll / contributions.length),
              'per transaction',
              AppColors.surfaceAlt,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color == AppColors.surfaceAlt ? AppColors.surface : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: color != AppColors.surfaceAlt ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: color == AppColors.surfaceAlt ? AppColors.textMuted : color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(fundRepositoryProvider).getAllContributions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }

        final contributions = snapshot.data!;
        final now = DateTime.now();
        
        // Get last 6 months data
        List<FlSpot> spots = [];
        for (int i = 5; i >= 0; i--) {
          final month = DateTime(now.year, now.month - i);
          final monthContribs = contributions.where((c) => 
            c.date.month == month.month && c.date.year == month.year
          );
          final total = monthContribs.fold<double>(0.0, (sum, c) => sum + c.amount);
          spots.add(FlSpot((5 - i).toDouble(), total));
        }

        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1000,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppColors.textMuted.withOpacity(0.1),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final months = ['J', 'F', 'M', 'A', 'M', 'J'];
                      if (value.toInt() >= 0 && value.toInt() < months.length) {
                        return Text(
                          months[value.toInt()],
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.3),
                        AppColors.primary.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopContributors(WidgetRef ref) {
    return FutureBuilder(
      future: Future.wait([
        ref.read(fundRepositoryProvider).getAllContributions(),
        ref.read(memberRepositoryProvider).getAllMembers(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final contribList = snapshot.data![0] as List<Contribution>;
        final memberList = snapshot.data![1] as List<Member>;

        Map<String, double> memberTotals = {};
        for (var contrib in contribList) {
          memberTotals.update(contrib.memberId, (v) => v + contrib.amount, ifAbsent: () => contrib.amount);
        }

        var sortedMembers = memberTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        sortedMembers = sortedMembers.take(5).toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: sortedMembers.asMap().entries.map((entry) {
              final index = entry.key;
              final memberData = entry.value;
              final member = memberList.cast<Member?>().firstWhere((m) => m?.id == memberData.key, orElse: () => null);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: index == 0 ? AppColors.primary.withOpacity(0.2) : AppColors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: index == 0 ? AppColors.primary : AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        member?.name ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(memberData.value),
                      style: TextStyle(
                        color: index == 0 ? AppColors.primary : AppColors.textPrimary,
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
    );
  }

  Widget _buildRecentContributions(WidgetRef ref) {
    return FutureBuilder(
      future: Future.wait([
        ref.read(fundRepositoryProvider).getAllContributions(),
        ref.read(memberRepositoryProvider).getAllMembers(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final contribList = snapshot.data![0] as List<Contribution>;
        final memberList = snapshot.data![1] as List<Member>;

        if (contribList.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('No contributions yet'),
            ),
          );
        }

        return Column(
          children: contribList.take(10).map((contrib) {
            final member = memberList.cast<Member?>().firstWhere((m) => m?.id == contrib.memberId, orElse: () => null);
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      member?.name[0].toUpperCase() ?? 'M',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member?.name ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${contrib.date.day}/${contrib.date.month}/${contrib.date.year}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(contrib.amount),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
