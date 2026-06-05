import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/member_with_status.dart';
import '../../modals/add_member_modal.dart';
import 'link_user_sheet.dart';

class MemberTileWithStatus extends ConsumerWidget {
  final MemberWithStatus memberStatus;

  const MemberTileWithStatus({super.key, required this.memberStatus});

  void _showLinkUserSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LinkUserSheet(
        memberId: memberStatus.member.id!,
        memberName: memberStatus.member.name,
        currentEmail: memberStatus.member.linkedEmail,
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMemberModal(existingMember: memberStatus.member),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            backgroundColor: statusColor.withAlpha(51),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name.toUpperCase(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (member.displayId.isNotEmpty) ...[
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          member.displayId,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
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
                if (member.linkedEmail != null) ...[
                  const Gap(4),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 12, color: AppColors.textMuted),
                      const Gap(4),
                      Text(
                        member.linkedEmail!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Gap(12),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(51),
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                color: AppColors.surfaceAlt,
                onSelected: (value) {
                  switch (value) {
                    case 'link':
                      _showLinkUserSheet(context);
                      break;
                    case 'edit':
                      _showEditSheet(context);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'link', child: ListTile(
                    leading: Icon(Icons.link, color: AppColors.primary),
                    title: Text('Link User'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  )),
                  const PopupMenuItem(value: 'edit', child: ListTile(
                    leading: Icon(Icons.edit, color: AppColors.secondary),
                    title: Text('Edit'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  )),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
