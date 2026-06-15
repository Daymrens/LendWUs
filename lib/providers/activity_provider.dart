import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/utils/growth_spots_calculator.dart';
import 'members_provider.dart';
import 'loans_provider.dart';

final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final comparisonMonthProvider = StateProvider<DateTime?>((ref) {
  final now = DateTime.now();
  final prev = DateTime(now.year, now.month - 1, 1);
  if (prev.month == 0) return DateTime(now.year - 1, 12, 1);
  return prev;
});

final showComparisonProvider = StateProvider<bool>((ref) => false);

final fundGrowthSpotsProvider = FutureProvider<List<FlSpot>>((ref) async {
  final contributions = [...?ref.watch(contributionsStreamProvider).asData?.value];
  final loans = [...?ref.watch(loansStreamProvider).asData?.value];
  final repayments = [...?ref.watch(repaymentsStreamProvider).asData?.value];
  final selected = ref.watch(selectedMonthProvider);
  return GrowthSpotsCalculator.compute(contributions, loans, repayments, selected.year, selected.month);
});

final comparisonGrowthSpotsProvider = FutureProvider<List<FlSpot>?>((ref) async {
  final show = ref.watch(showComparisonProvider);
  if (!show) return null;
  final contributions = [...?ref.watch(contributionsStreamProvider).asData?.value];
  final loans = [...?ref.watch(loansStreamProvider).asData?.value];
  final repayments = [...?ref.watch(repaymentsStreamProvider).asData?.value];
  final comp = ref.watch(comparisonMonthProvider);
  if (comp == null) return null;
  return GrowthSpotsCalculator.compute(contributions, loans, repayments, comp.year, comp.month);
});
