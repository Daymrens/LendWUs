import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted.withAlpha(80)),
            const Gap(16),
            Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const Gap(8),
              Text(subtitle!,
                style: TextStyle(color: AppColors.textMuted.withAlpha(150), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const Gap(24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
