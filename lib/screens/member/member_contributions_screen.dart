import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/contribution.dart';
import '../../data/models/member.dart';
import '../modals/member_payment_modal.dart';

final memberContributionsProvider = StreamProvider.family<List<Contribution>, String>((ref, memberId) {
  return ref.watch(contributionRepositoryProvider).watchMemberContributions(memberId);
});

class MemberContributionsScreen extends ConsumerStatefulWidget {
  const MemberContributionsScreen({super.key});

  @override
  ConsumerState<MemberContributionsScreen> createState() => _MemberContributionsScreenState();
}

class _MemberContributionsScreenState extends ConsumerState<MemberContributionsScreen> {
  int _chartMonths = 6;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).state;
    final memberId = user?.memberId;

    if (memberId == null) {
      return const Scaffold(
        body: Center(child: Text('Member ID not found')),
      );
    }

    final contributionsAsync = ref.watch(memberContributionsProvider(memberId));
    final settingsAsync = ref.watch(settingsProvider);
    final contributions = [...?contributionsAsync.asData?.value];
    final settings = settingsAsync.asData?.value;

    final now = DateTime.now();
    final members = [...?ref.watch(membersStreamProvider).asData?.value];
    final member = members.cast<Member?>().firstWhere((m) => m?.id == memberId, orElse: () => null);
    final thisMonth = contributions.where((c) =>
      c.date.month == now.month && c.date.year == now.year
    ).toList();
    final totalThisMonth = thisMonth.fold<double>(0.0, (s, c) => s + c.amount);
    final totalAll = contributions.fold<double>(0.0, (s, c) => s + c.amount);
    final memberHeads = member?.headsCount ?? 1;
    final memberAmountPerHead = member?.amountPerHead ?? 0;
    final memberTotalRequired = member?.totalRequired ?? 0.0;
    final requiredAmount = memberTotalRequired > 0
        ? memberTotalRequired
        : memberHeads * memberAmountPerHead;
    final balance = member?.balance ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Contributions'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.timeline),
            tooltip: 'Chart period',
            color: AppColors.surfaceAlt,
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
      body: contributionsAsync.when(
        data: (_) {
          if (contributions.isEmpty) {
            return const Center(child: Text('No contributions yet'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(memberContributionsProvider(memberId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressCard(totalThisMonth, totalAll, requiredAmount, contributions.length, balance, settings?.cutoffDay1 ?? 13, settings?.cutoffDay2 ?? 28),
                  const Gap(20),
                  _buildStatCards(contributions, totalThisMonth, totalAll),
                  const Gap(24),
                  Text(
                    'Monthly Trend',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const Gap(12),
                  _buildMonthlyChart(contributions),
                  const Gap(24),
                  Text(
                    'All Contributions',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const Gap(12),
                  _buildGroupedList(contributions),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final perHeadAmount = member?.amountPerHead ?? 0;
          final headCount = member?.headsCount ?? 1;
          final perCutoffAmount = perHeadAmount * headCount;
          final fullMonthlyRequired = perCutoffAmount * 2;

          if (totalThisMonth >= perCutoffAmount && fullMonthlyRequired > 0) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emoji_events, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(height: 16),
                    const Text("YOU'RE ON TRACK!",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You\'ve met your contribution for this cutoff period.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contributed: ${CurrencyFormatter.format(totalThisMonth)} / ${CurrencyFormatter.format(perCutoffAmount)} this cutoff',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              showModalBottomSheet(
                                context: context, isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const MemberPaymentModal(defaultAdvance: true),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Pay in Advance'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const MemberPaymentModal(),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Pay Contribution'),
      ),
    );
  }

  Widget _buildProgressCard(double totalThisMonth, double totalAll, double requiredPerHead, int count, double balance, int cutoffDay1, int cutoffDay2) {
    final progress = requiredPerHead > 0 ? (totalThisMonth / requiredPerHead).clamp(0.0, 1.0) : 0.0;
    final met = totalThisMonth >= requiredPerHead;

    // Cutoff status
    final now = DateTime.now();
    final today = now.day;
    final cutoffs = [cutoffDay1, cutoffDay2]..sort();
    int? nextCutoff;
    for (final c in cutoffs) {
      if (c >= today) { nextCutoff = c; break; }
    }
    nextCutoff ??= cutoffs.first;
    final daysUntilNext = nextCutoff - today;
    final paymentMet = requiredPerHead > 0 && totalThisMonth >= requiredPerHead;
    String cutoffLabel;
    Color cutoffColor;
    if (paymentMet) { cutoffLabel = '✓ Paid'; cutoffColor = AppColors.primary; }
    else if (daysUntilNext <= 0) { cutoffLabel = 'Due today'; cutoffColor = AppColors.warning; }
    else if (daysUntilNext <= 3) { cutoffLabel = '$daysUntilNext days to cutoff'; cutoffColor = Colors.orange; }
    else if (daysUntilNext <= 7) { cutoffLabel = '$daysUntilNext days to cutoff'; cutoffColor = AppColors.success; }
    else { cutoffLabel = 'Cutoff in $daysUntilNext days'; cutoffColor = AppColors.textMuted; }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Total Contributions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$count payments',
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(totalAll),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (requiredPerHead > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('This month: ${CurrencyFormatter.format(totalThisMonth)}',
                  style: TextStyle(
                    color: met ? AppColors.primary : AppColors.warning,
                    fontSize: 13, fontWeight: FontWeight.w600,
                  )),
                const Spacer(),
                Text('Required: ${CurrencyFormatter.format(requiredPerHead)}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceAlt,
                color: met ? AppColors.primary : AppColors.warning,
                minHeight: 6,
              ),
            ),
          ],
          if (balance > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, size: 16, color: AppColors.success),
                const Gap(6),
                Text('Credit balance: ${CurrencyFormatter.format(balance)}',
                  style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: cutoffColor),
              const Gap(6),
              Text(cutoffLabel, style: TextStyle(color: cutoffColor, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(List<Contribution> data, double totalThisMonth, double totalAll) {
    final now = DateTime.now();
    final lastMonth = data.where((c) {
      final lm = DateTime(now.year, now.month - 1);
      return c.date.month == lm.month && c.date.year == lm.year;
    }).toList();
    final totalLastMonth = lastMonth.fold<double>(0.0, (s, c) => s + c.amount);
    String changeLabel;
    Color changeColor;
    if (totalLastMonth <= 0 && totalThisMonth > 0) {
      changeLabel = '+100% vs last';
      changeColor = AppColors.primary;
    } else if (totalLastMonth > 0) {
      final pct = ((totalThisMonth - totalLastMonth) / totalLastMonth * 100);
      changeLabel = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% vs last';
      changeColor = pct >= 0 ? AppColors.primary : AppColors.warning;
    } else {
      changeLabel = 'No data last month';
      changeColor = AppColors.textMuted;
    }
    final avg = data.isEmpty ? 0.0 : totalAll / data.length;

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
          changeLabel,
          changeColor,
          Icons.calendar_month,
        ),
        _statCard(
          'Total',
          CurrencyFormatter.format(totalAll),
          '${data.length} transactions',
          AppColors.secondary,
          Icons.account_balance,
        ),
        _statCard(
          'Last Month',
          CurrencyFormatter.format(totalLastMonth),
          '${lastMonth.length} entries',
          AppColors.textMuted,
          Icons.history,
        ),
        _statCard(
          'Average',
          CurrencyFormatter.format(avg),
          'per transaction',
          AppColors.textMuted,
          Icons.calculate,
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color == AppColors.textMuted ? AppColors.surface : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: color != AppColors.textMuted ? Border.all(color: color.withAlpha(77)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(subtitle, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(List<Contribution> data) {
    final now = DateTime.now();
    final monthCount = _chartMonths > 0 ? _chartMonths : 12;
    final monthNames = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    List<FlSpot> spots = [];
    List<String> labels = [];

    final iterCount = _chartMonths > 0 ? monthCount : 12;
    for (int i = iterCount - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final monthContribs = data.where((c) =>
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
                          return Text(labels[i], style: TextStyle(color: AppColors.textMuted, fontSize: 11));
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
                  return Text(labels[i], style: TextStyle(color: AppColors.textMuted, fontSize: 11));
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

  Widget _buildGroupedList(List<Contribution> data) {
    final grouped = <String, List<Contribution>>{};
    for (var c in data) {
      final key = '${c.year}-${c.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(c);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: sortedKeys.map((key) {
        final items = grouped[key]!..sort((a, b) => b.date.compareTo(a.date));
        final monthTotal = items.fold<double>(0.0, (s, c) => s + c.amount);
        final parts = key.split('-');
        final monthName = DateFormatter.formatMonthYear(DateTime(int.parse(parts[0]), int.parse(parts[1])));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withAlpha(30),
                child: Text(parts[1], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              title: Text(monthName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: Text(CurrencyFormatter.format(monthTotal),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
              children: [
                const Divider(height: 1),
                ...items.map((c) => _buildContributionTile(c)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContributionTile(Contribution contribution) {
    final isAdmin = contribution.createdBy == 'admin';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isAdmin ? AppColors.warning.withAlpha(51) : AppColors.success.withAlpha(51),
        child: Icon(
          isAdmin ? Icons.admin_panel_settings : Icons.check,
          color: isAdmin ? AppColors.warning : AppColors.success,
          size: 18,
        ),
      ),
      title: Text(
        CurrencyFormatter.format(contribution.amount),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Row(
        children: [
          Text(_formatDate(contribution.date)),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Admin',
                style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ],
          if (contribution.createdBy == 'system') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Balance',
                style: TextStyle(color: AppColors.info, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => _showContributionDetails(contribution),
    );
  }

  void _showContributionDetails(Contribution contribution) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContributionDetailsSheet(contribution: contribution),
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

class _ContributionDetailsSheet extends StatelessWidget {
  final Contribution contribution;
  const _ContributionDetailsSheet({required this.contribution});

  @override
  Widget build(BuildContext context) {
    final isAdmin = contribution.createdBy == 'admin';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withAlpha(77),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(20),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isAdmin ? AppColors.warning.withAlpha(51) : AppColors.success.withAlpha(51),
                child: Icon(
                  isAdmin ? Icons.admin_panel_settings : Icons.check,
                  color: isAdmin ? AppColors.warning : AppColors.success,
                  size: 24,
                ),
              ),
              const Gap(16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyFormatter.format(contribution.amount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    _formatDetailDate(contribution.date),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const Gap(24),
          _detailRow(context, 'Month', '${contribution.month}/${contribution.year}'),
          if (contribution.notes != null && contribution.notes!.isNotEmpty)
            _detailRow(context, 'Notes', contribution.notes!),
          _detailRow(context, 'Source', isAdmin ? 'Logged by Admin' : contribution.createdBy == 'system' ? 'Balance Application' : 'Member Payment'),
          const Gap(24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatDetailDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year} at ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
