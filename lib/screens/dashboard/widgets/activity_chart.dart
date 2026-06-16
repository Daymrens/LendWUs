import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/activity_provider.dart';

class ActivityChart extends ConsumerStatefulWidget {
  const ActivityChart({super.key});

  @override
  ConsumerState<ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends ConsumerState<ActivityChart> {
  @override
  Widget build(BuildContext context) {
    final spotsAsync = ref.watch(fundGrowthSpotsProvider);
    final compSpotsAsync = ref.watch(comparisonGrowthSpotsProvider);
    final showComp = ref.watch(showComparisonProvider);
    final selected = ref.watch(selectedMonthProvider);
    final textMuted = AppColors.textMuted;

    final monthLabel = '${_monthName(selected.month)} ${selected.year}';
    final daysInMonth = DateTime(selected.year, selected.month + 1, 0).day;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () {
                  final cur = ref.read(selectedMonthProvider);
                  ref.read(selectedMonthProvider.notifier).state =
                      DateTime(cur.year, cur.month - 1, 1);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: textMuted,
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const Gap(8),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () {
                  final cur = ref.read(selectedMonthProvider);
                  ref.read(selectedMonthProvider.notifier).state =
                      DateTime(cur.year, cur.month + 1, 1);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: textMuted,
              ),
              const Gap(12),
              GestureDetector(
                onTap: () => ref.read(showComparisonProvider.notifier).state = !showComp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: showComp ? AppColors.secondary.withAlpha(40) : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showComp ? Icons.compare_arrows : Icons.compare,
                        size: 14,
                        color: showComp ? AppColors.secondary : textMuted,
                      ),
                      const Gap(4),
                      Text(
                        'Compare',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: showComp ? AppColors.secondary : textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showComp) ...[
            const Gap(4),
            Row(
              children: [
                const Gap(8),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 16),
                  onPressed: () {
                    final cur = ref.read(comparisonMonthProvider) ?? selected;
                    ref.read(comparisonMonthProvider.notifier).state =
                        DateTime(cur.year, cur.month - 1, 1);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.secondary,
                ),
                const Gap(4),
                Consumer(
                  builder: (_, ref, __) {
                    final comp = ref.watch(comparisonMonthProvider);
                    final label = comp != null
                        ? '${_monthName(comp.month)} ${comp.year}'
                        : 'Select month';
                    return Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                const Gap(4),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 16),
                  onPressed: () {
                    final cur = ref.read(comparisonMonthProvider) ?? selected;
                    ref.read(comparisonMonthProvider.notifier).state =
                        DateTime(cur.year, cur.month + 1, 1);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.secondary,
                ),
              ],
            ),
          ],
          const Gap(12),
          SizedBox(
            height: 200,
            child: spotsAsync.when(
              data: (spots) {
                final compSpots = compSpotsAsync.valueOrNull;

                if (spots.isEmpty && (compSpots == null || compSpots.isEmpty)) {
                  return Center(
                    child: Text('No data for this month', style: TextStyle(color: textMuted)),
                  );
                }

                final allValues = [...spots.map((s) => s.y)];
                if (compSpots != null) allValues.addAll(compSpots.map((s) => s.y));
                final minY = allValues.reduce((a, b) => a < b ? a : b);
                final maxY = allValues.reduce((a, b) => a > b ? a : b);
                final yRange = maxY - minY;
                final yPadding = yRange > 0 ? yRange * 0.1 : maxY * 0.1;
                final adjustedMin = (minY - yPadding).clamp(0.0, double.infinity);
                final adjustedMax = maxY + yPadding;

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
                          reservedSize: 55,
                          interval: _niceInterval(adjustedMin, adjustedMax, 4),
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                _formatAxisValue(value),
                                style: TextStyle(fontSize: 10, color: textMuted),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: _dayInterval(daysInMonth),
                          getTitlesWidget: (value, meta) {
                            if (value < 1 || value > daysInMonth) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                value.toInt().toString(),
                                style: TextStyle(fontSize: 10, color: textMuted),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: adjustedMin,
                    maxY: adjustedMax,
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => AppColors.surfaceAlt,
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final isComp = compSpots != null &&
                                spot.barIndex == 1;
                            return LineTooltipItem(
                              'Day ${spot.x.toInt()}\n${CurrencyFormatter.format(spot.y)}',
                              TextStyle(
                                color: isComp ? AppColors.secondary : AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: spots.length <= 5,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 3,
                              color: AppColors.primary,
                              strokeWidth: 0,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: compSpots == null,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withAlpha(76),
                              AppColors.primary.withAlpha(0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      if (compSpots != null)
                        LineChartBarData(
                          spots: compSpots.isEmpty ? [const FlSpot(0, 0)] : compSpots,
                          isCurved: true,
                          color: AppColors.secondary,
                          barWidth: 2,
                          dashArray: [6, 3],
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.secondary.withAlpha(60),
                                AppColors.secondary.withAlpha(0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Text(
                  'Chart error',
                  style: TextStyle(color: AppColors.warning.withAlpha(128)),
                ),
              ),
            ),
          ),
          if (showComp) ...[
            const Gap(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(AppColors.primary, monthLabel),
                const Gap(16),
                Consumer(
                  builder: (_, ref, __) {
                    final comp = ref.watch(comparisonMonthProvider);
                    final label = comp != null
                        ? '${_monthName(comp.month)} ${comp.year}'
                        : 'Comparison';
                    return _legendDot(AppColors.secondary, label, dashed: true);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month.clamp(1, 12)];
  }

  Widget _legendDot(Color color, String label, {bool dashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Gap(4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  String _formatAxisValue(double value) {
    if (value >= 1000000) {
      return '₱${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '₱${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    }
    return '₱${value.toStringAsFixed(0)}';
  }

  double _niceInterval(double min, double max, int targetCount) {
    final range = max - min;
    if (range <= 0) return 1000;
    final raw = range / targetCount;
    final magnitude = _pow10((raw.abs()).toStringAsFixed(0).length - 1);
    final normalized = raw / magnitude;
    double nice;
    if (normalized <= 1.5) nice = 1;
    else if (normalized <= 3) nice = 2;
    else if (normalized <= 7) nice = 5;
    else nice = 10;
    return nice * magnitude;
  }

  double _pow10(int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) result *= 10;
    return result;
  }

  double _dayInterval(int daysInMonth) {
    if (daysInMonth <= 7) return 1;
    if (daysInMonth <= 14) return 2;
    if (daysInMonth <= 21) return 3;
    return (daysInMonth / 6).ceilToDouble();
  }
}
