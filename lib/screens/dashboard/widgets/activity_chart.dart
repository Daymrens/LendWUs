import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/activity_provider.dart';

class ActivityChart extends ConsumerWidget {
  const ActivityChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(fundGrowthSpotsProvider);

    return SizedBox(
      height: 150,
      child: spotsAsync.when(
        data: (spots) => LineChart(
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
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withAlpha(76), // 0.3 * 255
                      AppColors.primary.withAlpha(0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Chart error',
            style: TextStyle(color: AppColors.warning.withAlpha(128)),
          ),
        ),
      ),
    );
  }
}
