import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/loans_provider.dart';
import '../../../providers/members_with_status_provider.dart';

class DonutChartsRow extends ConsumerWidget {
  const DonutChartsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Expanded(child: _LoanStatusChart()),
        const Gap(12),
        const Expanded(child: _PaymentStatusChart()),
      ],
    );
  }
}

class _LoanStatusChart extends ConsumerWidget {
  const _LoanStatusChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLoansAsync = ref.watch(loansStreamProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: allLoansAsync.when(
        data: (allLoans) {
          final now = DateTime.now();
          final active = allLoans.where((l) => !l.isFullyRepaid).toList();
          final repaid = allLoans.where((l) => l.isFullyRepaid).toList();
          final overdue = active.where((l) => l.dueDate.isBefore(now)).toList();
          final onTime = active.where((l) => !l.dueDate.isBefore(now)).toList();
          final total = allLoans.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Loan Status',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Gap(8),
              if (total == 0)
                SizedBox(
                  height: 120,
                  child: Center(
                    child: Text('No loans yet',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 24,
                            sections: _buildPieSections(
                                onTime.length, overdue.length, repaid.length, total),
                          ),
                        ),
                      ),
                      const Gap(8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _legendDot('On Time', AppColors.primary, '${onTime.length}'),
                          const Gap(4),
                          _legendDot('Overdue', AppColors.warning, '${overdue.length}'),
                          const Gap(4),
                          _legendDot('Repaid', AppColors.secondary, '${repaid.length}'),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => const SizedBox(
          height: 120,
          child: Center(child: Text('Error', style: TextStyle(fontSize: 12))),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
      int onTime, int overdue, int repaid, int total) {
    final sections = <PieChartSectionData>[];
    if (onTime > 0) {
      sections.add(PieChartSectionData(
        value: onTime / total * 100,
        color: AppColors.primary,
        radius: 28,
        title: '${(onTime / total * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (overdue > 0) {
      sections.add(PieChartSectionData(
        value: overdue / total * 100,
        color: AppColors.warning,
        radius: 28,
        title: '${(overdue / total * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (repaid > 0) {
      sections.add(PieChartSectionData(
        value: repaid / total * 100,
        color: AppColors.secondary,
        radius: 28,
        title: '${(repaid / total * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    return sections;
  }

  Widget _legendDot(String label, Color color, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const Gap(4),
        Text('$label ($count)',
            style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

class _PaymentStatusChart extends ConsumerWidget {
  const _PaymentStatusChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersStatusAsync = ref.watch(membersWithStatusProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: membersStatusAsync.when(
        data: (membersWithStatus) {
          final paid = membersWithStatus.where((m) => m.paymentStatus == 'Paid').length;
          final pending = membersWithStatus.where((m) => m.paymentStatus == 'Pending').length;
          final partial = membersWithStatus
              .where((m) =>
                  m.paymentStatus != 'Paid' &&
                  m.paymentStatus != 'Pending' &&
                  m.paymentStatus != 'Overdue')
              .length;
          final overdue = membersWithStatus
              .where((m) => m.paymentStatus == 'Overdue')
              .length;
          final total = membersWithStatus.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Status',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Gap(8),
              if (total == 0)
                SizedBox(
                  height: 120,
                  child: Center(
                    child: Text('No members',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 24,
                            sections: _buildPieSections(
                                paid, pending, partial, overdue, total),
                          ),
                        ),
                      ),
                      const Gap(8),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _legendDot('Paid', AppColors.primary, '$paid'),
                            const Gap(4),
                            _legendDot('Pending', AppColors.warning, '$pending'),
                            if (partial > 0) ...[
                              const Gap(4),
                              _legendDot('Partial', AppColors.secondary, '$partial'),
                            ],
                            if (overdue > 0) ...[
                              const Gap(4),
                              _legendDot('Overdue', const Color(0xFFEF4444), '$overdue'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => const SizedBox(
          height: 120,
          child: Center(child: Text('Error', style: TextStyle(fontSize: 12))),
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
      int paid, int pending, int partial, int overdue, int total) {
    final sections = <PieChartSectionData>[];
    if (paid > 0) {
      sections.add(PieChartSectionData(
        value: paid / total * 100,
        color: AppColors.primary,
        radius: 28,
        title: '${(paid / total * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (pending > 0) {
      sections.add(PieChartSectionData(
        value: pending / total * 100,
        color: AppColors.warning,
        radius: 28,
        title: '${(pending / total * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (partial > 0) {
      sections.add(PieChartSectionData(
        value: partial / total * 100,
        color: AppColors.secondary,
        radius: 28,
        title: '${(partial / total * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (overdue > 0) {
      sections.add(PieChartSectionData(
        value: overdue / total * 100,
        color: const Color(0xFFEF4444),
        radius: 28,
        title: '${(overdue / total * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    return sections;
  }

  Widget _legendDot(String label, Color color, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const Gap(4),
        Text('$label ($count)',
            style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
