import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final textMuted = colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: textMuted.withValues(alpha: 0.3)),
            const Gap(16),
            Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: textMuted,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const Gap(8),
              Text(subtitle!,
                style: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 13),
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
