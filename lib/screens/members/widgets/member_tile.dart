import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/fund_repository.dart';

class MemberTile extends StatelessWidget {
  final Member member;
  final FundRepository contributions;

  const MemberTile({
    super.key,
    required this.member,
    required this.contributions,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getMemberContributions(),
      builder: (context, snapshot) {
        final totalContributed = snapshot.data ?? 0.0;
        final progress = member.totalRequired > 0
            ? (totalContributed / member.totalRequired).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                child: Text(
                  member.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name.toUpperCase(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Gap(4),
                    Text(
                      '${member.headsCount} Heads · ${CurrencyFormatter.format(totalContributed)} / ${CurrencyFormatter.format(member.totalRequired)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Gap(8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.surfaceAlt,
                      color: progress >= 1.0 ? AppColors.primary : AppColors.secondary,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (progress >= 1.0 ? AppColors.primary : AppColors.warning)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  progress >= 1.0 ? 'Paid' : '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    color: progress >= 1.0 ? AppColors.primary : AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<double> _getMemberContributions() async {
    final allContributions = await contributions.getAllContributions();
    final memberContributions = allContributions.where((c) => c.memberId == member.id);
    return memberContributions.fold<double>(0.0, (sum, c) => sum + c.amount);
  }
}
