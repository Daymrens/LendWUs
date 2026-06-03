import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../data/models/contribution.dart';
import '../modals/member_payment_modal.dart';

final memberContributionsProvider = FutureProvider.family<List<Contribution>, String>((ref, memberId) async {
  final repo = ContributionRepository();
  return await repo.getMemberContributions(memberId);
});

class MemberContributionsScreen extends ConsumerWidget {
  const MemberContributionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).state;
    final memberId = user?.memberId;
    
    if (memberId == null) {
      return const Scaffold(
        body: Center(child: Text('Member ID not found')),
      );
    }

    final contributionsAsync = ref.watch(memberContributionsProvider(memberId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Contributions'),
      ),
      body: contributionsAsync.when(
        data: (contributions) {
          final total = contributions.fold<double>(
            0,
            (sum, c) => sum + c.amount,
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(memberContributionsProvider(memberId));
            },
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  color: AppColors.cardBackground,
                  child: Column(
                    children: [
                      Text(
                        'Total Contributions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyFormatter.format(total),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${contributions.length} payments',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: contributions.isEmpty
                      ? const Center(
                          child: Text('No contributions yet'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: contributions.length,
                          itemBuilder: (context, index) {
                            final contribution = contributions[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.success.withOpacity(0.2),
                                  child: Icon(
                                    Icons.check,
                                    color: AppColors.success,
                                  ),
                                ),
                                title: Text(
                                  CurrencyFormatter.format(contribution.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  DateFormatter.format(contribution.date),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const MemberPaymentModal(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Pay Contribution'),
      ),
    );
  }
}
