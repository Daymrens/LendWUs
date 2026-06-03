import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/member.dart';
import '../../providers/members_provider.dart';

class IntroductionScreen extends StatefulWidget {
  const IntroductionScreen({super.key});

  @override
  State<IntroductionScreen> createState() => _IntroductionScreenState();
}

class _IntroductionScreenState extends State<IntroductionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSetupPage = false;

  final List<IntroPage> _pages = [
    IntroPage(
      title: 'Welcome to\nSinking Fund',
      description: 'Manage your group savings, track contributions, and issue loans - all in one place.',
      icon: Icons.account_balance_wallet,
      color: AppColors.primary,
    ),
    IntroPage(
      title: 'Track\nContributions',
      description: 'Keep track of member contributions and monitor payment status in real-time.',
      icon: Icons.people,
      color: AppColors.secondary,
    ),
    IntroPage(
      title: 'Manage\nLoans',
      description: 'Issue loans from the fund pool, track repayments, and calculate interest automatically.',
      icon: Icons.trending_up,
      color: AppColors.warning,
    ),
    IntroPage(
      title: 'Monthly\nReports',
      description: 'View detailed monthly reports, fund growth charts, and contribution summaries.',
      icon: Icons.assessment,
      color: AppColors.primary,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_isSetupPage) {
      return QuickSetupScreen(onComplete: _completeIntro);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeIntro,
                child: const Text('SKIP', style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            _buildIndicators(),
            const Gap(32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage == _pages.length - 1) {
                      setState(() => _isSetupPage = true);
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'QUICK SETUP' : 'NEXT',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(IntroPage page) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: page.color,
            ),
          ),
          const Gap(48),
          Text(
            page.title,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 36,
                  height: 1.2,
                ),
            textAlign: TextAlign.center,
          ),
          const Gap(24),
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 16,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? _pages[_currentPage].color
                : AppColors.textMuted.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class QuickSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const QuickSetupScreen({super.key, required this.onComplete});

  @override
  ConsumerState<QuickSetupScreen> createState() => _QuickSetupScreenState();
}

class _QuickSetupScreenState extends ConsumerState<QuickSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberOfMembersController = TextEditingController(text: '10');
  final _contributionController = TextEditingController(text: '150');

  @override
  void dispose() {
    _numberOfMembersController.dispose();
    _contributionController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('number_of_members', int.parse(_numberOfMembersController.text));
      await prefs.setDouble('default_contribution', double.parse(_contributionController.text));

      // Create placeholder members
      final numberOfMembers = int.parse(_numberOfMembersController.text);
      final defaultContribution = double.parse(_contributionController.text);
      final repo = ref.read(memberRepositoryProvider);

      for (int i = 1; i <= numberOfMembers; i++) {
        final member = Member(
          name: 'Member $i',
          headsCount: 1,
          amountPerHead: defaultContribution,
          totalRequired: defaultContribution,
          joinedAt: DateTime.now(),
        );
        await repo.addMember(member);
      }

      ref.invalidate(membersProvider);
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(40),
                Text(
                  'Quick Setup',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const Gap(16),
                Text(
                  'Let\'s set up your sinking fund with some basic information.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const Gap(48),
                TextFormField(
                  controller: _numberOfMembersController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Members',
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter number of members';
                    final num = int.tryParse(value);
                    if (num == null || num < 1) return 'Must be at least 1';
                    if (num > 100) return 'Maximum 100 members';
                    return null;
                  },
                ),
                const Gap(24),
                TextFormField(
                  controller: _contributionController,
                  decoration: const InputDecoration(
                    labelText: 'Default Contribution per Cut-off',
                    prefixIcon: Icon(Icons.money),
                    border: OutlineInputBorder(),
                    suffixText: 'PHP',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter contribution amount';
                    if (double.tryParse(value) == null) return 'Invalid amount';
                    return null;
                  },
                ),
                const Gap(16),
                Text(
                  'You can change member names and contribution amounts later in the Members section.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'COMPLETE SETUP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const Gap(16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: TextButton(
                    onPressed: widget.onComplete,
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
                const Gap(32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IntroPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  IntroPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
