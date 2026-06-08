import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';

class QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class ActionButtonsRow extends StatelessWidget {
  final VoidCallback onNewContribution;
  final VoidCallback onIssueLoan;
  final VoidCallback onRecordRepayment;
  final VoidCallback? onBackfillIds;
  final VoidCallback? onViewMembers;
  final VoidCallback? onViewReports;
  final VoidCallback? onViewApprovals;

  const ActionButtonsRow({
    super.key,
    required this.onNewContribution,
    required this.onIssueLoan,
    required this.onRecordRepayment,
    this.onBackfillIds,
    this.onViewMembers,
    this.onViewReports,
    this.onViewApprovals,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      QuickAction(icon: Icons.add_circle, label: 'Contribution', color: AppColors.primary, onTap: onNewContribution),
      QuickAction(icon: Icons.account_balance, label: 'Issue Loan', color: AppColors.secondary, onTap: onIssueLoan),
      QuickAction(icon: Icons.payment, label: 'Repayment', color: AppColors.warning, onTap: onRecordRepayment),
      if (onBackfillIds != null)
        QuickAction(icon: Icons.refresh, label: 'Backfill IDs', color: AppColors.primary, onTap: onBackfillIds!),
      if (onViewMembers != null)
        QuickAction(icon: Icons.people, label: 'Members', color: AppColors.info, onTap: onViewMembers!),
      if (onViewReports != null)
        QuickAction(icon: Icons.assessment, label: 'Reports', color: AppColors.textMuted, onTap: onViewReports!),
      if (onViewApprovals != null)
        QuickAction(icon: Icons.approval, label: 'Approvals', color: AppColors.success, onTap: onViewApprovals!),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: action.onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(action.icon, color: action.color, size: 28),
                  const Gap(8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        action.label,
                        style: TextStyle(
                          color: action.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
