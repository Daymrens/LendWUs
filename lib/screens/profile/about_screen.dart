import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                    size: 56, color: AppColors.primary),
                ),
                const Gap(16),
                Text('LendWUs',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold, letterSpacing: -1)),
                const Gap(4),
                const Text('Version 1.0.0',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          const Gap(32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Gap(12),
                const Text(
                  'LendWUs is a group savings and loan management application. '
                  'It helps members track contributions, manage loans, and '
                  'stay on top of payments with real-time updates and notifications.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          const Gap(16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Features', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Gap(12),
                _featureItem(Icons.payments_outlined, 'Contribution tracking with receipt upload'),
                _featureItem(Icons.emoji_events_outlined, 'Group savings pool management'),
                _featureItem(Icons.trending_up, 'Loan issuance and repayment tracking'),
                _featureItem(Icons.assessment, 'Monthly reports and fund growth charts'),
                _featureItem(Icons.notifications_active, 'Push notifications for updates and reminders'),
              ],
            ),
          ),
          const Gap(16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Legal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Gap(12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Terms of Service', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {},
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Privacy Policy', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {},
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Licenses', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => showLicensePage(context: context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const Gap(10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
