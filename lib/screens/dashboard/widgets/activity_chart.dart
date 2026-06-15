import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/activity_provider.dart';
import '../../../providers/fund_provider.dart';

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
    final fundBalance = ref.watch(fundBalanceProvider).valueOrNull ?? 0;

    final monthLabel = '${_monthName(selected.month)} ${selected.year}';

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
                color: AppColors.textMuted,
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
                color: AppColors.textMuted,
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
                        color: showComp ? AppColors.secondary : AppColors.textMuted,
                      ),
                      const Gap(4),
                      Text(
                        'Compare',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: showComp ? AppColors.secondary : AppColors.textMuted,
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
            height: 150,
            child: spotsAsync.when(
              data: (spots) {
                final compSpots = compSpotsAsync.valueOrNull;
                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
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
}
