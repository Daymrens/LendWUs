import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/chart_data_provider.dart';

class CollectionRateChart extends ConsumerWidget {
  const CollectionRateChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(collectionRateTrendProvider);
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
            'Collection Rate Trend',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Gap(16),
          SizedBox(
            height: 160,
            child: trendsAsync.when(
              data: (trends) {
                if (trends.every((t) => t.rate == 0)) {
                  return Center(
                    child: Text('No data available', style: TextStyle(color: textMuted)),
                  );
                }

                final spots = <FlSpot>[];
                for (int i = 0; i < trends.length; i++) {
                  spots.add(FlSpot(i.toDouble(), trends[i].rate));
                }

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: textMuted.withAlpha(26),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                '${value.toInt()}%',
                                style: TextStyle(fontSize: 9, color: textMuted),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= trends.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                trends[idx].label.split(' ').first,
                                style: TextStyle(fontSize: 8, color: textMuted),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 100,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => AppColors.surfaceAlt,
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final idx = spot.x.toInt();
                            final trend = idx >= 0 && idx < trends.length ? trends[idx] : null;
                            return LineTooltipItem(
                              trend != null
                                  ? '${trend.label}\n${trend.rate.toStringAsFixed(1)}%\n₱${trend.collected.toStringAsFixed(0)} / ₱${trend.required.toStringAsFixed(0)}'
                                  : '',
                              TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.warning,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 3,
                              color: spot.y >= 80 ? AppColors.primary : spot.y >= 50 ? AppColors.warning : AppColors.textMuted,
                              strokeWidth: 2,
                              strokeColor: AppColors.surface,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.warning.withAlpha(60),
                              AppColors.warning.withAlpha(0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      LineChartBarData(
                        spots: const [FlSpot(0, 80), FlSpot(5, 80)],
                        isCurved: false,
                        color: AppColors.primary.withAlpha(50),
                        barWidth: 1,
                        dashArray: [4, 4],
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => Center(
                child: Text('Chart error', style: TextStyle(color: AppColors.warning.withAlpha(128))),
              ),
            ),
          ),
          const Gap(4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 2, decoration: BoxDecoration(color: AppColors.primary.withAlpha(50), borderRadius: BorderRadius.circular(1))),
              const Gap(4),
              Text('Target 80%', style: TextStyle(fontSize: 9, color: textMuted)),
              const Gap(16),
              Container(width: 10, height: 2, decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(1))),
              const Gap(4),
              Text('Collection Rate', style: TextStyle(fontSize: 9, color: textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
