import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/members_provider.dart';

class TopContributors extends ConsumerWidget {
  const TopContributors({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersStreamProvider);
    final contributionsAsync = ref.watch(contributionsStreamProvider);
    final textMuted = AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Contributors This Month',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const Gap(16),
        membersAsync.when(
          data: (members) {
            final contributions = [...?contributionsAsync.asData?.value];
            final now = DateTime.now();
            final monthContribs = contributions.where((c) =>
              c.date.month == now.month && c.date.year == now.year
            ).toList();

            final memberTotals = <String, double>{};
            for (final c in monthContribs) {
              memberTotals[c.memberId] = (memberTotals[c.memberId] ?? 0) + c.amount;
            }

            final sorted = memberTotals.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            final top = sorted.take(5).toList();

            if (top.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('No contributions this month', style: TextStyle(color: textMuted)),
                  ),
                ),
              );
            }

            final maxAmount = top.first.value;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 200,
                  child: Column(
                    children: top.asMap().entries.map((entry) {
                      final i = entry.key;
                      final entryData = entry.value;
                      final member = members.where((m) => m.id == entryData.key).firstOrNull;
                      final name = member?.name ?? 'Unknown';
                      final amount = entryData.value;
                      final pct = maxAmount > 0 ? amount / maxAmount : 0.0;
                      final barColor = i == 0 ? AppColors.primary : i == 1 ? AppColors.secondary : AppColors.textMuted.withAlpha(100);

                      return Padding(
                        padding: EdgeInsets.only(bottom: i < top.length - 1 ? 8 : 0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text(
                                '#${i + 1}',
                                style: TextStyle(
                                  color: i < 3 ? AppColors.primary : textMuted,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary.withAlpha(25),
                              child: Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                            const Gap(8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Gap(2),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: pct.clamp(0.0, 1.0),
                                      backgroundColor: barColor.withAlpha(30),
                                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(8),
                            Text(
                              CurrencyFormatter.format(amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
          loading: () => const Card(child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )),
          error: (_, __) => const Card(child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Error loading data')),
          )),
        ),
      ],
    );
  }
}
