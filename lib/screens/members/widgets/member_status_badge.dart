import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MemberStatusBadge extends StatelessWidget {
  final String status;

  const MemberStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Paid':
        color = AppColors.primary;
        break;
      case 'Pending':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.secondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
