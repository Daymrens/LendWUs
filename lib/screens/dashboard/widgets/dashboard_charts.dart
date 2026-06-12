import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/activity_provider.dart';
import '../../../providers/loans_provider.dart';

class DashboardCharts extends ConsumerStatefulWidget {
   DashboardCharts({super.key});

  @override
  ConsumerState<DashboardCharts> createState() => _DashboardChartsState();
}

class _DashboardChartsState extends ConsumerState<DashboardCharts> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Charts', style: Theme.of(context).textTheme.displayMedium),
             Spacer(),
            _TabChip(label: 'Trend', index: 0, selected: _selectedTab == 0, onTap: () => setState(() => _selectedTab = 0)),
             Gap(8),
            _TabChip(label: 'Loans', index: 1, selected: _selectedTab == 1, onTap: () => setState(() => _selectedTab = 1)),
          ],
        ),
         Gap(16),
        _selectedTab == 0 ?  _TrendChart() :  _LoanPieChart(),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final int index;
  final bool selected;
  final VoidCallback onTap;

   _TabChip({required this.label, required this.index, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:  EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.textMuted.withAlpha(77)),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _TrendChart extends ConsumerWidget {
   _TrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(fundGrowthSpotsProvider);

    return Container(
      height: 180,
      padding:  EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: spotsAsync.when(
        data: (spots) => LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(
                color: AppColors.textMuted.withAlpha(26),
                strokeWidth: 1,
              ),
            ),
            titlesData:  FlTitlesData(
              show: false,
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots.isEmpty ? [ FlSpot(0, 0)] : spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 3,
                dotData:  FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withAlpha(76), AppColors.primary.withAlpha(0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () =>  Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text('Chart error', style: TextStyle(color: AppColors.warning.withAlpha(128))),
        ),
      ),
    );
  }
}

class _LoanPieChart extends ConsumerWidget {
   _LoanPieChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLoansAsync = ref.watch(loansStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return allLoansAsync.when(
      data: (allLoans) {
        final now = DateTime.now();
        final active = allLoans.where((l) => !l.isFullyRepaid).toList();
        final repaid = allLoans.where((l) => l.isFullyRepaid).toList();
        final overdue = active.where((l) => l.dueDate.isBefore(now)).toList();
        final onTime = active.where((l) => !l.dueDate.isBefore(now)).toList();
        final total = allLoans.length;

        if (total == 0) {
          return Container(
            height: 180,
            padding:  EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text('No loans yet', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ),
          );
        }

        return Container(
          height: 200,
          padding:  EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: _buildPieSections(onTime.length, overdue.length, repaid.length, total),
                  ),
                ),
              ),
               Gap(16),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legendDot('On Time', AppColors.primary, '${onTime.length}'),
                   Gap(8),
                  _legendDot('Overdue', AppColors.warning, '${overdue.length}'),
                   Gap(8),
                  _legendDot('Repaid', AppColors.secondary, '${repaid.length}'),
                ],
              ),
            ],
          ),
        );
      },
      loading: () =>  SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
      error: (_, __) =>  SizedBox(height: 180, child: Center(child: Text('Error'))),
    );
  }

  List<PieChartSectionData> _buildPieSections(int onTime, int overdue, int repaid, int total) {
    final sections = <PieChartSectionData>[];
    if (onTime > 0) {
      sections.add(PieChartSectionData(
        value: onTime / total * 100,
        color: AppColors.primary,
        radius: 35,
        title: '${(onTime / total * 100).toStringAsFixed(0)}%',
        titleStyle:  TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (overdue > 0) {
      sections.add(PieChartSectionData(
        value: overdue / total * 100,
        color: AppColors.warning,
        radius: 35,
        title: '${(overdue / total * 100).toStringAsFixed(0)}%',
        titleStyle:  TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (repaid > 0) {
      sections.add(PieChartSectionData(
        value: repaid / total * 100,
        color: AppColors.secondary,
        radius: 35,
        title: '${(repaid / total * 100).toStringAsFixed(0)}%',
        titleStyle:  TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    return sections;
  }

  Widget _legendDot(String label, Color color, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
         Gap(6),
        Text('$label ($count)', style:  TextStyle(fontSize: 12)),
      ],
    );
  }
}
