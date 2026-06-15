import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/unrecognized_screen.dart';
import 'screens/auth/biometric_verify_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/members/members_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/contributions/contributions_screen.dart';
import 'screens/loans/loans_screen.dart';
import 'screens/onboarding/introduction_screen.dart';
import 'screens/member/member_dashboard_screen.dart';
import 'screens/member/member_contributions_screen.dart';
import 'screens/member/member_loans_screen.dart';
import 'screens/member/member_requests_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/help_support_screen.dart';
import 'screens/profile/about_screen.dart';
import 'screens/profile/privacy_security_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/changelog_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/member/member_pay_screen.dart';
import 'screens/member/loan_calculator.dart';
import 'screens/treasurer/treasurer_dashboard_screen.dart';
import 'data/models/payment_request.dart';

import 'screens/admin/approvals_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/admin/admin_data_screen.dart';
import 'screens/admin/member_balance_screen.dart';
import 'screens/admin/member_profile_screen.dart';
import 'screens/admin/bulk_loan_processing.dart';
import 'screens/admin/compliance_reports.dart';
import 'screens/admin/member_migration.dart';
import 'screens/admin/send_notification_screen.dart';
import 'screens/admin/backup_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/activity/activity_feed_screen.dart';
import 'screens/search/global_search_screen.dart';
import 'core/utils/currency_formatter.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'core/services/notification_service.dart';

final onboardingCompleteProvider = StateProvider<bool>((ref) => false);

Future<void> bootstrapOnboardingFlag(WidgetRef ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('onboarding_complete') ?? false;
    ref.read(onboardingCompleteProvider.notifier).state = value;
  } catch (_) {
    // ignore; default to false
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(currentUserProvider);
  final settingsAsync = ref.watch(settingsProvider);
  final onboardingComplete = ref.watch(onboardingCompleteProvider);

  return GoRouter(
    navigatorKey: notificationNavKey,
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final user = authNotifier.state;
      final isRecognized = authNotifier.isRecognized;
      final isAdmin = authNotifier.isAdmin;

      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';
      final isIntro = location == '/intro';
      final isUnrecognized = location == '/unrecognized';
      final isMemberRoute = location == '/member-home' ||
          location == '/member-contributions' ||
          location == '/member-loans' ||
          location == '/member-requests' ||
          location == '/member-profile' ||
          location == '/member-loan-calculator' ||
          location == '/member-treasurer';
      final isPublicRoute = isLoggingIn || isIntro || isUnrecognized ||
          location == '/biometric-verify' ||
          location == '/changelog' ||
          location == '/help' || location == '/about' ||
          location == '/privacy-security' || location == '/edit-profile' ||
          location == '/notifications' || location == '/member-pay' ||
          location == '/maintenance';

      final settings = settingsAsync.valueOrNull;
      final maintenanceMode = settings?.isMaintenanceMode ?? false;

      // Maintenance mode: block non-admin users from all app routes
      if (maintenanceMode && !isAdmin && !isPublicRoute) {
        return '/maintenance';
      }

      // Unrecognized → redirect to home if recognized
      if (authNotifier.isFirebaseUser && isRecognized && isUnrecognized) {
        return isAdmin ? '/' : '/member-home';
      }

      // Firebase user but unrecognized → go to unrecognized page
      if (authNotifier.isFirebaseUser && !isRecognized && !isUnrecognized) {
        return '/unrecognized';
      }

      // No Firebase user → login (unless already there)
      if (!authNotifier.isFirebaseUser && !isPublicRoute) {
        return '/login';
      }

      // Already logged in and recognized → redirect from login/auth pages
      if (user != null && isRecognized && isLoggingIn) {
        return isAdmin ? '/' : '/member-home';
      }

      // Biometric required → verify unless already there
      if (user != null && isRecognized && authNotifier.isBiometricRequired && location != '/biometric-verify') {
        return '/biometric-verify';
      }

      // Intro → skip if completed
      if (isIntro && onboardingComplete) {
        return '/login';
      }

      // Route-level auth: prevent crossing between admin and member shells
      if (isRecognized && isAdmin && isMemberRoute) {
        return '/';
      }
      if (isRecognized && !isAdmin && !isPublicRoute && !isMemberRoute && !isLoggingIn) {
        return '/member-home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/intro',
        builder: (context, state) => const IntroductionScreen(),
      ),
      GoRoute(
        path: '/biometric-verify',
        builder: (context, state) => const BiometricVerifyScreen(),
      ),
      GoRoute(
        path: '/unrecognized',
        builder: (context, state) => const UnrecognizedScreen(),
      ),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/changelog',
        builder: (context, state) => const ChangelogScreen(),
      ),
      GoRoute(
        path: '/privacy-security',
        builder: (context, state) => const PrivacySecurityScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/member-pay',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final loanId = extra?['loanId'] as String?;
          final paymentTypeStr = extra?['paymentType'] as String?;
          final paymentType = paymentTypeStr == 'loan'
              ? PaymentType.loan
              : PaymentType.contribution;
          return MemberPayScreen(loanId: loanId, paymentType: paymentType);
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AdminScaffoldWithNavBar(location: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/members',
            builder: (context, state) => const MembersScreen(),
          ),
          GoRoute(
            path: '/contributions',
            builder: (context, state) => const ContributionsScreen(),
          ),
          GoRoute(
            path: '/loans',
            builder: (context, state) => const LoansScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/approvals',
            builder: (context, state) => const ApprovalsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const AdminSettingsScreen(),
          ),
          GoRoute(
            path: '/data-management',
            builder: (context, state) => const AdminDataScreen(),
          ),
          GoRoute(
            path: '/member-balances',
            builder: (context, state) => const MemberBalanceScreen(),
          ),
          GoRoute(
            path: '/member-profile/:memberId',
            builder: (context, state) => AdminMemberProfileScreen(
              memberId: state.pathParameters['memberId']!,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/bulk-loans',
            builder: (context, state) => const BulkLoanProcessingScreen(),
          ),
          GoRoute(
            path: '/compliance-reports',
            builder: (context, state) => const ComplianceReportsScreen(),
          ),
          GoRoute(
            path: '/member-migration',
            builder: (context, state) => const MemberMigrationScreen(),
          ),
          GoRoute(
            path: '/send-notification',
            builder: (context, state) => const SendNotificationScreen(),
          ),
          GoRoute(
            path: '/activity',
            builder: (context, state) => const ActivityFeedScreen(),
          ),
          GoRoute(
            path: '/backups',
            builder: (context, state) => const BackupScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const GlobalSearchScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MemberScaffoldWithNavBar(location: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(
            path: '/member-home',
            builder: (context, state) => const MemberDashboardScreen(),
          ),
          GoRoute(
            path: '/member-contributions',
            builder: (context, state) => const MemberContributionsScreen(),
          ),
          GoRoute(
            path: '/member-loans',
            builder: (context, state) => const MemberLoansScreen(),
          ),
          GoRoute(
            path: '/member-requests',
            builder: (context, state) => const MemberRequestsScreen(),
          ),
          GoRoute(
            path: '/member-profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/member-loan-calculator',
            builder: (context, state) => const LoanCalculatorScreen(),
          ),
          GoRoute(
            path: '/member-treasurer',
            builder: (context, state) => const TreasurerDashboardScreen(),
          ),
        ],
      ),
    ],
  );
});

class SinkingFundApp extends ConsumerStatefulWidget {
  const SinkingFundApp({super.key});

  @override
  ConsumerState<SinkingFundApp> createState() => _SinkingFundAppState();
}

class _SinkingFundAppState extends ConsumerState<SinkingFundApp> {
  @override
  void initState() {
    super.initState();
    bootstrapOnboardingFlag(ref);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (previous, next) {
      next.whenData((settings) {
        CurrencyFormatter.updateConfiguration(
          settings.currencySymbol,
          settings.currencyCode,
        );
      });
    });

    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(goRouterProvider);

    AppColors.init(themeMode == ThemeMode.light ? Brightness.light : Brightness.dark);

    return MaterialApp.router(
      title: 'LendWUs',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (child == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child;
      },
    );
  }
}

class AdminScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  final String location;

  const AdminScaffoldWithNavBar({
    super.key,
    required this.child,
    required this.location,
  });

  int _getSelectedIndex() {
    if (location == '/') return 0;
    if (location == '/members') return 1;
    if (location == '/contributions') return 2;
    if (location == '/loans') return 3;
    if (location == '/reports') return 4;
    if (location == '/profile') return 5;
    return 6;
  }

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/members');
        break;
      case 2:
        context.go('/contributions');
        break;
      case 3:
        context.go('/loans');
        break;
      case 4:
        context.go('/reports');
        break;
      case 5:
        context.go('/profile');
        break;
      case 6:
        _showMoreMenu(context);
        break;
    }
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('More Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _moreTile(ctx, Icons.approval, 'Approvals', () { Navigator.pop(ctx); context.push('/approvals'); }),
                _moreTile(ctx, Icons.settings, 'Settings', () { Navigator.pop(ctx); context.push('/settings'); }),
                _moreTile(ctx, Icons.storage, 'Data Mgmt', () { Navigator.pop(ctx); context.push('/data-management'); }),
                _moreTile(ctx, Icons.account_balance_wallet, 'Balances', () { Navigator.pop(ctx); context.push('/member-balances'); }),
                _moreTile(ctx, Icons.add_circle, 'Bulk Loans', () { Navigator.pop(ctx); context.push('/bulk-loans'); }),
                _moreTile(ctx, Icons.verified, 'Compliance', () { Navigator.pop(ctx); context.push('/compliance-reports'); }),
                _moreTile(ctx, Icons.swap_horiz, 'Migration', () { Navigator.pop(ctx); context.push('/member-migration'); }),
                _moreTile(ctx, Icons.notifications_active, 'Notify', () { Navigator.pop(ctx); context.push('/send-notification'); }),
                _moreTile(ctx, Icons. history, 'Activity', () { Navigator.pop(ctx); context.push('/activity'); }),
                _moreTile(ctx, Icons.search, 'Search', () { Navigator.pop(ctx); context.push('/search'); }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _moreTile(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomNavigationBar(
            currentIndex: _getSelectedIndex(),
            onTap: (index) => _onNavTap(context, index),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Members'),
              BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Contribs'),
              BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Loans'),
              BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Reports'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
              BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
            ],
          ),
        ],
      ),
    );
  }
}

class MemberScaffoldWithNavBar extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const MemberScaffoldWithNavBar({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  ConsumerState<MemberScaffoldWithNavBar> createState() => _MemberScaffoldWithNavBarState();
}

class _MemberScaffoldWithNavBarState extends ConsumerState<MemberScaffoldWithNavBar> {
  int _getSelectedIndex() {
    if (widget.location == '/member-home') return 0;
    if (widget.location == '/member-contributions') return 1;
    if (widget.location == '/member-loans') return 3;
    if (widget.location == '/member-profile') return 4;
    return 0;
  }

  void _showActionSheet() {
    final isTreasurer = ref.read(currentUserProvider).isTreasurer;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12, runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _actionTile(ctx, Icons.payment, 'Submit Payment', () { Navigator.pop(ctx); context.go('/member-pay'); }),
                _actionTile(ctx, Icons.add_chart, 'Apply for Loan', () { Navigator.pop(ctx); context.go('/member-loan-calculator'); }),
                _actionTile(ctx, Icons.request_page, 'My Requests', () { Navigator.pop(ctx); context.go('/member-requests'); }),
                if (isTreasurer)
                  _actionTile(ctx, Icons.account_balance, 'Treasurer', () { Navigator.pop(ctx); context.go('/member-treasurer'); }),
                _actionTile(ctx, Icons.notifications, 'Notifications', () { Navigator.pop(ctx); context.go('/notifications'); }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getSelectedIndex(),
        onTap: (index) {
          if (index == 2) {
            _showActionSheet();
            return;
          }
          switch (index) {
            case 0:
              context.go('/member-home');
              break;
            case 1:
              context.go('/member-contributions');
              break;
            case 3:
              context.go('/member-loans');
              break;
            case 4:
              context.go('/member-profile');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Contribs'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Loans'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
