import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/member_with_status.dart';

class MemberTileWithStatus extends StatelessWidget {
  final MemberWithStatus memberStatus;

  const MemberTileWithStatus({super.key, required this.memberStatus});

  @override
  Widget build(BuildContext context) {
    final member = memberStatus.member;
    final progress = memberStatus.progress;

    Color statusColor;
    switch (memberStatus.statusColor) {
      case 'green':
        statusColor = AppColors.primary;
        break;
      case 'orange':
        statusColor = AppColors.warning;
        break;
      default:
        statusColor = AppColors.secondary;
    }

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
            backgroundColor: statusColor.withOpacity(0.2),
            child: Text(
              member.name[0].toUpperCase(),
              style: TextStyle(
                color: statusColor,
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
                  '${member.headsCount} Heads · ${CurrencyFormatter.format(memberStatus.amountPaid)} / ${CurrencyFormatter.format(memberStatus.requiredAmount)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Gap(8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceAlt,
                  color: statusColor,
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
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              memberStatus.paymentStatus,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
