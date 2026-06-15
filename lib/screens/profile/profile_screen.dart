import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/members_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/services/notification_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _notificationsEnabled = true;
  late final AnimationController _animCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final granted = await NotificationService.requestPermission();
      setState(() => _notificationsEnabled = granted);
      if (granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications enabled')),
        );
      }
    } else {
      setState(() => _notificationsEnabled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications disabled. Manage in device settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(currentUserProvider);
    final user = auth.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: user?.photoUrl != null 
                        ? NetworkImage(user!.photoUrl!) 
                        : null,
                      child: user?.photoUrl == null 
                        ? const Icon(Icons.person, size: 60, color: AppColors.primary)
                        : null,
                    ),
                    const Gap(16),
                Text(
                  user?.username ?? 'Unknown User',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (user?.displayId != null) ...[
                  const Gap(4),
                  Text(
                    'ID: ${user!.displayId}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ],
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: (auth.isAdmin ? Colors.orange : Colors.blue).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    auth.isAdmin ? 'Administrator' : 'Member',
                    style: TextStyle(
                      color: auth.isAdmin ? Colors.orange : Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
          ),
          if (user?.memberId != null) ...[
            const Gap(24),
            _MemberStatsSection(memberId: user!.memberId!),
          ],
          const Gap(40),
          Text(
            'Account Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            subtitle: const Text('Change display name and photo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/edit-profile'),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Theme'),
            subtitle: Text(
              ref.watch(themeModeProvider) == ThemeMode.dark ? 'Dark mode enabled' : 'Light mode enabled',
            ),
            trailing: Switch(
              value: ref.watch(themeModeProvider) == ThemeMode.dark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),
          if (auth.isAdmin)
            ListTile(
              leading: const Icon(Icons.settings_applications),
              title: const Text('Fund Settings'),
              subtitle: const Text('Configure payment limits and currency'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings'),
            ),
          if (auth.isAdmin) ...[
            const Gap(24),
            Text(
              'Admin Tools',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Approvals'),
              subtitle: const Text('Approve payments, loans, and head changes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/approvals'),
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Data Management'),
              subtitle: const Text('Browse and edit Firestore data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/data-management'),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Member Balances'),
              subtitle: const Text('View member balances overview'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/member-balances'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Bulk Loan Processing'),
              subtitle: const Text('Issue multiple loans via CSV'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/bulk-loans'),
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows),
              title: const Text('Member Migration'),
              subtitle: const Text('Transfer records between members'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/member-migration'),
            ),
            ListTile(
              leading: const Icon(Icons.assessment),
              title: const Text('Compliance Reports'),
              subtitle: const Text('View aggregated compliance stats'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/compliance-reports'),
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Send Notification'),
              subtitle: const Text('Broadcast custom or app-update alerts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/send-notification'),
            ),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backups'),
              subtitle: const Text('Create, list, and manage data backups'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/backups'),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Manage your alerts'),
            trailing: Switch(value: _notificationsEnabled, onChanged: _toggleNotifications),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy & Security'),
            subtitle: const Text('Manage your data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/privacy-security'),
          ),
          const Gap(24),
          Text(
            'More',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('Loan Calculator'),
            subtitle: const Text('Estimate monthly payments and interest'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/member-loan-calculator'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/help'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
          const Gap(32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: auth.isLoading
                  ? null
                  : () async {
                      await ref.read(currentUserProvider).logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: auth.isLoading
                    ? const SizedBox(
                        key: ValueKey('spinner'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                      )
                    : const Icon(Icons.logout, key: ValueKey('icon')),
              ),
              label: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  auth.isLoading ? 'Logging out…' : 'Log Out',
                  key: ValueKey(auth.isLoading ? 'logging' : 'logout'),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const Gap(40),
        ],
      ),
    );
  }
}

class _MemberStatsSection extends ConsumerWidget {
  final String memberId;

  const _MemberStatsSection({required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberByIdProvider(memberId));
    return memberAsync.when(
      data: (member) {
        if (member == null) return const SizedBox();
        final joinedDate = DateFormat('MMM d, yyyy').format(member.joinedAt);
        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Member Info',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant.withAlpha(30)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _statItem('Heads', '${member.headsCount}', AppColors.primary)),
                      Container(height: 32, width: 1, color: AppColors.textMuted.withAlpha(30)),
                      Expanded(child: _statItem('Per Head', CurrencyFormatter.format(member.amountPerHead), AppColors.secondary)),
                      Container(height: 32, width: 1, color: AppColors.textMuted.withAlpha(30)),
                      Expanded(child: _statItem('Required', CurrencyFormatter.format(member.totalRequired), AppColors.warning)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, size: 16, color: member.balance > 0 ? AppColors.success : AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text('Balance: ${CurrencyFormatter.format(member.balance)}',
                              style: TextStyle(
                                color: member.balance > 0 ? AppColors.success : AppColors.textMuted,
                                fontWeight: FontWeight.w600, fontSize: 13,
                              )),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text('Since $joinedDate',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}
