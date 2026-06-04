import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/activity_items_provider.dart';

class RecentActivityList extends ConsumerWidget {
  const RecentActivityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(unifiedActivityProvider);
    final displayItems = items.take(10).toList();

    if (displayItems.isEmpty) {
      return const Center(child: Text('No recent activity'));
    }

    return Column(
      children: displayItems.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _colorForType(item.type).withAlpha(51),
                child: Icon(
                  _iconForType(item.type),
                  color: _colorForType(item.type),
                  size: 18,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.memberName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${_labelForType(item.type)}${item.description != null ? ' · ${item.description}' : ''} · ${_formatDate(item.date)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.format(item.amount),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: _colorForType(item.type),
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'contribution':
        return AppColors.primary;
      case 'loan':
        return AppColors.warning;
      case 'repayment':
        return AppColors.secondary;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'contribution':
        return Icons.add_circle;
      case 'loan':
        return Icons.account_balance;
      case 'repayment':
        return Icons.payment;
      default:
        return Icons.circle;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'contribution':
        return 'Contribution';
      case 'loan':
        return 'Loan issued';
      case 'repayment':
        return 'Repayment';
      default:
        return 'Activity';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}
