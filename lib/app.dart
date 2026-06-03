import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'data/models/user.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/members/members_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/contributions/contributions_screen.dart';
import 'screens/loans/loans_screen.dart';
import 'screens/onboarding/introduction_screen.dart';
import 'screens/member/member_dashboard_screen.dart';
import 'screens/member/member_contributions_screen.dart';
import 'screens/member/member_requests_screen.dart';

import 'screens/admin/approvals_screen.dart';

class SinkingFundApp extends ConsumerWidget {
  const SinkingFundApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Sinking Fund',
      theme: AppTheme.darkTheme,
      routerConfig: _createRouter(ref),
    );
  }

  GoRouter _createRouter(WidgetRef ref) {
    final authNotifier = ref.watch(currentUserProvider);
    
    return GoRouter(
      initialLocation: '/login',
      refreshListenable: authNotifier,
      redirect: (context, state) async {
        final user = ref.read(currentUserProvider).state;
        final prefs = await SharedPreferences.getInstance();
        final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
        
        final isLoggingIn = state.matchedLocation == '/login';
        final isIntro = state.matchedLocation == '/intro';

        // If not logged in, redirect to login (except for intro)
        if (user == null && !isIntro && !isLoggingIn) {
          return '/login';
        }
        
        // If logged in, skip login screen
        if (user != null && isLoggingIn) {
          return user.role == UserRole.admin ? '/' : '/member-home';
        }
        
        // Handle intro screen
        if (isIntro && onboardingComplete) {
          return '/login';
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
        // Admin routes
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
          ],
        ),
        // Member routes
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
              path: '/member-requests',
              builder: (context, state) => const MemberRequestsScreen(),
            ),
          ],
        ),
      ],
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
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getSelectedIndex(),
        onTap: (index) {
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
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Members',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Contributions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Loans',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

class MemberScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  final String location;

  const MemberScaffoldWithNavBar({
    super.key, 
    required this.child,
    required this.location,
  });

  int _getSelectedIndex() {
    if (location == '/member-home') return 0;
    if (location == '/member-contributions') return 1;
    if (location == '/member-requests') return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getSelectedIndex(),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/member-home');
              break;
            case 1:
              context.go('/member-contributions');
              break;
            case 2:
              context.go('/member-requests');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'My Contributions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: 'Requests',
          ),
        ],
      ),
    );
  }
}
