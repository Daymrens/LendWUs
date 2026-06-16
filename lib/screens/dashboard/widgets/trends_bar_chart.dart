import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/chart_data_provider.dart';

class TrendsBarChart extends ConsumerWidget {
  const TrendsBarChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(monthlyTrendsProvider);
    final textMuted = AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Trends (6 months)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Gap(16),
          SizedBox(
            height: 220,
            child: trendsAsync.when(
              data: (trends) {
                if (trends.every((t) => t.contributions == 0 && t.loans == 0 && t.repayments == 0)) {
                  return Center(
                    child: Text('No data available', style: TextStyle(color: textMuted)),
                  );
                }
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _maxValue(trends) * 1.2,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => AppColors.surfaceAlt,
                        tooltipRoundedRadius: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final trend = trends[group.x.toInt()];
                          final label = rodIndex == 0 ? 'Contributions' : rodIndex == 1 ? 'Loans' : 'Repayments';
                          return BarTooltipItem(
                            '${trend.label}\n$label: ${CurrencyFormatter.format(rod.toY)}',
                            TextStyle(
                              color: rodIndex == 0 ? AppColors.primary : rodIndex == 1 ? AppColors.warning : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                _formatShort(value),
                                style: TextStyle(fontSize: 9, color: textMuted),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= trends.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                trends[idx].label.split(' ').first,
                                style: TextStyle(fontSize: 9, color: textMuted),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: textMuted.withAlpha(26),
                        strokeWidth: 1,
                      ),
                    ),
                    barGroups: List.generate(trends.length, (i) {
                      final t = trends[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: t.contributions,
                            color: AppColors.primary,
                            width: 8,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                          ),
                          BarChartRodData(
                            toY: t.loans,
                            color: AppColors.warning,
                            width: 8,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                          ),
                          BarChartRodData(
                            toY: t.repayments,
                            color: AppColors.secondary,
                            width: 8,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => Center(
                child: Text('Chart error', style: TextStyle(color: AppColors.warning.withAlpha(128))),
              ),
            ),
          ),
          const Gap(12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem('Contributions', AppColors.primary),
              const Gap(16),
              _legendItem('Loans', AppColors.warning),
              const Gap(16),
              _legendItem('Repayments', AppColors.secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const Gap(4),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }

  double _maxValue(List<MonthlyTrend> trends) {
    double max = 0;
    for (final t in trends) {
      if (t.contributions > max) max = t.contributions;
      if (t.loans > max) max = t.loans;
      if (t.repayments > max) max = t.repayments;
    }
    return max;
  }

  String _formatShort(double value) {
    if (value >= 1000000) return '₱${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '₱${(value / 1000).toStringAsFixed(0)}K';
    return '₱${value.toStringAsFixed(0)}';
  }
}
