import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/member_with_status.dart';
import '../../providers/members_with_status_provider.dart';
import 'widgets/member_tile_with_status.dart';
import '../modals/add_member_modal.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  int _selectedTab = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _tabs = ['All', 'Active', 'Pending', 'Overdue'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersWithStatus = ref.watch(membersWithStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
      ),
      body: membersWithStatus.when(
        data: (allMembers) {
          final filtered = _filterMembers(allMembers);
          final activeCount = allMembers.where((m) => m.paymentStatus == 'Paid').length;
          final pendingCount = allMembers.where((m) => m.paymentStatus == 'Pending').length;
          final overdueCount = allMembers.where((m) => m.paymentStatus == 'Overdue').length;
          final totalContributions = allMembers.fold<double>(0.0, (sum, m) => sum + m.amountPaid);

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                color: AppColors.surface,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search members...',
                        prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: AppColors.textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Gap(12),
                    Row(
                      children: _tabs.asMap().entries.map((entry) {
                        final i = entry.key;
                        final label = entry.value;
                        final isActive = i == _selectedTab;
                        return Padding(
                          padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.primary : AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isActive ? Colors.white : AppColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Gap(12),
                    Row(
                      children: [
                        _chip('$activeCount Active', AppColors.primary),
                        const Gap(8),
                        _chip('$pendingCount Pending', AppColors.warning),
                        const Gap(8),
                        _chip('$overdueCount Overdue', AppColors.error),
                        const Spacer(),
                        Text(
                          'This Month: ${CurrencyFormatter.format(totalContributions)}',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const Gap(12),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(membersWithStatusProvider);
                  },
                  child: filtered.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: AppColors.textMuted),
                                const Gap(12),
                                Text(
                                  allMembers.isEmpty ? 'No members yet' : 'No matches',
                                  style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final memberStatus = filtered[index];
                            return GestureDetector(
                              onTap: () => context.push('/member-profile/${memberStatus.member.id}'),
                              child: MemberTileWithStatus(memberStatus: memberStatus),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading members')),
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

  List<MemberWithStatus> _filterMembers(List<MemberWithStatus> members) {
    var result = members;
    switch (_selectedTab) {
      case 1:
        result = result.where((m) => m.paymentStatus == 'Paid').toList();
        break;
      case 2:
        result = result.where((m) => m.paymentStatus == 'Pending').toList();
        break;
      case 3:
        result = result.where((m) => m.paymentStatus == 'Overdue').toList();
        break;
    }
    if (_searchQuery.isNotEmpty) {
      result = result.where((m) => m.member.name.toLowerCase().contains(_searchQuery)).toList();
    }
    return result;
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
