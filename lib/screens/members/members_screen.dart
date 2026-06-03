import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/members_with_status_provider.dart';
import '../../providers/fund_provider.dart';
import 'widgets/member_tile_with_status.dart';
import '../modals/add_member_modal.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersWithStatus = ref.watch(membersWithStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    _buildTab('All', true),
                    const Gap(8),
                    _buildTab('Active', false),
                    const Gap(8),
                    _buildTab('Pending', false),
                  ],
                ),
                const Gap(16),
                membersWithStatus.when(
                  data: (list) {
                    return FutureBuilder(
                      future: _getTotalContributions(ref),
                      builder: (context, snapshot) {
                        final total = snapshot.data ?? 0.0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${list.length} Members',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Total: ${CurrencyFormatter.format(total)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading members'),
                ),
              ],
            ),
          ),
          Expanded(
            child: membersWithStatus.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.textMuted,
                        ),
                        const Gap(16),
                        Text(
                          'No members yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          'Tap + to add your first member',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    return MemberTileWithStatus(memberStatus: list[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Error loading members')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AddMemberModal(),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<double> _getTotalContributions(WidgetRef ref) async {
    final contributions = await ref.read(fundRepositoryProvider).getAllContributions();
    return contributions.fold<double>(0.0, (sum, c) => sum + c.amount);
  }

  Widget _buildTab(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : AppColors.textMuted,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
