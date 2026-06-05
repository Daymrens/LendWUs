import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/member.dart';
import '../../providers/members_provider.dart';
import '../modals/new_contribution_modal.dart';

class ContributionsScreen extends ConsumerStatefulWidget {
  const ContributionsScreen({super.key});

  @override
  ConsumerState<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends ConsumerState<ContributionsScreen> {
  int _chartMonths = 6;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceAlt = Theme.of(context).brightness == Brightness.dark
        ? AppColors.surfaceAlt
        : AppColors.lightSurfaceAlt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contributions'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.timeline),
            tooltip: 'Chart period',
            color: surfaceAlt,
            onSelected: (v) => setState(() => _chartMonths = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 3, child: Text('3 months', style: TextStyle(color: _chartMonths == 3 ? AppColors.primary : null))),
              PopupMenuItem(value: 6, child: Text('6 months', style: TextStyle(color: _chartMonths == 6 ? AppColors.primary : null))),
              PopupMenuItem(value: 12, child: Text('12 months', style: TextStyle(color: _chartMonths == 12 ? AppColors.primary : null))),
              PopupMenuItem(value: 0, child: Text('All time', style: TextStyle(color: _chartMonths == 0 ? AppColors.primary : null))),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(contributionsStreamProvider);
          ref.invalidate(membersStreamProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by member name...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const Gap(16),
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
    final contributionsAsync = ref.watch(contributionsStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return contributionsAsync.when(
      data: (contributions) {
        final now = DateTime.now();
        final thisMonth = contributions.where((c) => 
          c.date.month == now.month && c.date.year == now.year
        ).toList();
        final lastMonth = contributions.where((c) {
          final lm = DateTime(now.year, now.month - 1);
          return c.date.month == lm.month && c.date.year == lm.year;
        }).toList();
        final totalThisMonth = thisMonth.fold<double>(0.0, (sum, c) => sum + c.amount);
        final totalLastMonth = lastMonth.fold<double>(0.0, (sum, c) => sum + c.amount);
        final totalAll = contributions.fold<double>(0.0, (sum, c) => sum + c.amount);
        final percentChange = totalLastMonth > 0 
          ? ((totalThisMonth - totalLastMonth) / totalLastMonth * 100)
          : 0.0;
        final avg = contributions.isEmpty ? 0.0 : totalAll / contributions.length;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _statCard(
              'This Month',
              CurrencyFormatter.format(totalThisMonth),
              percentChange >= 0 ? '+${percentChange.toStringAsFixed(1)}% vs last' : '${percentChange.toStringAsFixed(1)}% vs last',
              percentChange >= 0 ? AppColors.primary : AppColors.warning,
              Icons.calendar_month,
            ),
            _statCard(
              'Total',
              CurrencyFormatter.format(totalAll),
              '${contributions.length} transactions',
              AppColors.secondary,
              Icons.account_balance,
            ),
            _statCard(
              'Last Month',
              CurrencyFormatter.format(totalLastMonth),
              '${lastMonth.length} entries',
              colorScheme.onSurfaceVariant,
              Icons.history,
            ),
            _statCard(
              'Average',
              CurrencyFormatter.format(avg),
              'per transaction',
              colorScheme.onSurfaceVariant,
              Icons.calculate,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading contributions')),
    );
  }

  Widget _statCard(String title, String value, String subtitle, Color color, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMuted = color == colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMuted ? colorScheme.surface : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: !isMuted ? Border.all(color: color.withAlpha(77)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(value, style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(subtitle, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(WidgetRef ref) {
    final contributionsAsync = ref.watch(contributionsStreamProvider);
    return contributionsAsync.when(
      data: (contributions) {
        final now = DateTime.now();
        final monthCount = _chartMonths > 0 ? _chartMonths : 12;

        List<FlSpot> spots = [];
        List<String> labels = [];
        final monthNames = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

        int iterCount = _chartMonths > 0 ? monthCount : 12;
        for (int i = iterCount - 1; i >= 0; i--) {
          final month = DateTime(now.year, now.month - i);
          final monthContribs = contributions.where((c) => 
            c.date.month == month.month && c.date.year == month.year
          );
          final total = monthContribs.fold<double>(0.0, (sum, c) => sum + c.amount);
          spots.add(FlSpot((iterCount - 1 - i).toDouble(), total));
          labels.add(monthNames[month.month - 1]);
        }

        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _chartMonths == 0
              ? _buildBarChart(spots, labels)
              : LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: AppColors.textMuted.withValues(alpha: 0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, m) {
                            final i = v.toInt();
                            if (i >= 0 && i < labels.length) {
                              return Text(labels[i], style: const TextStyle(color: AppColors.textMuted, fontSize: 11));
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
                            colors: [AppColors.primary.withAlpha(77), AppColors.primary.withValues(alpha: 0.0)],
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
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(height: 200, child: Center(child: Text('Error'))),
    );
  }

  Widget _buildBarChart(List<FlSpot> spots, List<String> labels) {
    final maxY = spots.isEmpty ? 1.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i >= 0 && i < labels.length) {
                  return Text(labels[i], style: const TextStyle(color: AppColors.textMuted, fontSize: 11));
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
        gridData: const FlGridData(show: false),
        barGroups: spots.asMap().entries.map((e) {
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(
              toY: e.value.y,
              color: AppColors.primary,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildTopContributors(WidgetRef ref) {
    final contribsAsync = ref.watch(contributionsStreamProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    return contribsAsync.when(
      data: (contribList) {
        return membersAsync.when(
          data: (memberList) {
            Map<String, double> memberTotals = {};
            for (var contrib in contribList) {
              memberTotals.update(contrib.memberId, (v) => v + contrib.amount, ifAbsent: () => contrib.amount);
            }

            var sorted = memberTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            sorted = sorted.take(5).toList();
            final maxVal = sorted.isEmpty ? 1.0 : sorted.first.value;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: sorted.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  final member = memberList.cast<Member?>().firstWhere((m) => m?.id == e.key, orElse: () => null);
                  final fraction = maxVal > 0 ? e.value / maxVal : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: i == 0 ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceAlt,
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text('${i + 1}', style: TextStyle(
                            color: i == 0 ? AppColors.primary : AppColors.textMuted,
                            fontWeight: FontWeight.bold, fontSize: 12,
                          ))),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member?.name ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const Gap(4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  backgroundColor: AppColors.surfaceAlt,
                                  color: i == 0 ? AppColors.primary : AppColors.secondary,
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(12),
                        Text(CurrencyFormatter.format(e.value),
                          style: TextStyle(
                            color: i == 0 ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: FontWeight.bold, fontSize: 13,
                          )),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading members')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading contributions')),
    );
  }

  Widget _buildRecentContributions(WidgetRef ref) {
    final contribsAsync = ref.watch(contributionsStreamProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    return contribsAsync.when(
      data: (contribList) {
        return membersAsync.when(
          data: (memberList) {
            var filtered = contribList.toList();
            if (_searchQuery.isNotEmpty) {
              filtered = filtered.where((c) {
                final member = memberList.cast<Member?>().firstWhere((m) => m?.id == c.memberId, orElse: () => null);
                return (member?.name ?? '').toLowerCase().contains(_searchQuery);
              }).toList();
            }

            if (filtered.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: Text('No contributions yet')),
              );
            }

            return Column(
              children: filtered.take(10).map((contrib) {
                final member = memberList.cast<Member?>().firstWhere((m) => m?.id == contrib.memberId, orElse: () => null);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          (member?.name ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member?.name ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(_formatDate(contrib.date),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(CurrencyFormatter.format(contrib.amount),
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('#${contrib.id?.substring(0, 4) ?? ''}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading members')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading contributions')),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
