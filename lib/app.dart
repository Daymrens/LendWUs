import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/unrecognized_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/members/members_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/contributions/contributions_screen.dart';
import 'screens/loans/loans_screen.dart';
import 'screens/onboarding/introduction_screen.dart';
import 'screens/member/member_dashboard_screen.dart';
import 'screens/member/member_contributions_screen.dart';
import 'screens/member/member_requests_screen.dart';
import 'screens/profile/profile_screen.dart';

import 'screens/admin/approvals_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'core/utils/currency_formatter.dart';
import 'providers/settings_provider.dart';

class SinkingFundApp extends ConsumerWidget {
  const SinkingFundApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to settings and update CurrencyFormatter
    ref.listen(settingsProvider, (previous, next) {
      next.whenData((settings) {
        CurrencyFormatter.updateConfiguration(
          settings.currencySymbol,
          settings.currencyCode,
        );
      });
    });

    return MaterialApp.router(
      title: 'LendWUs',
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
        final auth = ref.read(currentUserProvider);
        final user = auth.state;
        final isRecognized = auth.isRecognized;
        final prefs = await SharedPreferences.getInstance();
        final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
        
        final isLoggingIn = state.matchedLocation == '/login';
        final isIntro = state.matchedLocation == '/intro';
        final isUnrecognized = state.matchedLocation == '/unrecognized';
        final isAuthPage = isLoggingIn || isIntro || isUnrecognized;

        // Has Firebase Auth but no Firestore doc → unrecognized
        if (auth.isFirebaseUser && !isRecognized && !isUnrecognized) {
          return '/unrecognized';
        }
        
        // Not signed in at all → login
        if (!auth.isFirebaseUser && !isAuthPage) {
          return '/login';
        }

        // If logged in and recognized, skip login screen
        if (user != null && isRecognized && isLoggingIn) {
          return auth.isAdmin ? '/' : '/member-home';
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
        GoRoute(
          path: '/unrecognized',
          builder: (context, state) => const UnrecognizedScreen(),
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
            GoRoute(
              path: '/settings',
              builder: (context, state) => const AdminSettingsScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
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
            GoRoute(
              path: '/member-profile',
              builder: (context, state) => const ProfileScreen(),
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
    if (location == '/profile') return 5;
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
            case 5:
              context.go('/profile');
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
            label: 'Contribs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Loans',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
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
    if (location == '/member-profile') return 3;
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
            case 3:
              context.go('/member-profile');
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
            label: 'My Contribs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
