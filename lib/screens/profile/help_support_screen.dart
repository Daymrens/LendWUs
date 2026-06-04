import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent, size: 48, color: AppColors.primary),
                const Gap(12),
                Text('How can we help you?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Gap(8),
                const Text('Reach out to us through any of the channels below.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center),
              ],
            ),
          ),
          const Gap(24),
          Text('Contact', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Gap(12),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
            ),
            title: const Text('Email Us'),
            subtitle: const Text('support@lendwus.com'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () {
              Clipboard.setData(const ClipboardData(text: 'support@lendwus.com'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email address copied to clipboard')),
              );
            },
          ),
          const Gap(8),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chat_outlined, color: AppColors.primary, size: 20),
            ),
            title: const Text('Live Chat'),
            subtitle: const Text('Available Mon-Fri 9AM-6PM'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Gap(24),
          Text('Frequently Asked Questions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Gap(12),
          _faqTile(context, 'How do contributions work?',
            'Each member has a required contribution per head per month. '
            'Payments are submitted with a receipt and approved by an admin. '
            'You can pay any amount up to your total required.'),
          _faqTile(context, 'How are loans processed?',
            'Loan requests are reviewed by admins. Once approved, the amount is disbursed from the fund pool. '
            'Repayments include interest and are tracked per loan.'),
          _faqTile(context, 'What are the cutoff dates?',
            'Payments are due on two cutoff dates each month (configurable by admin). '
            'You can pay early or on time. The app shows your cutoff status.'),
          _faqTile(context, 'Can I change my number of heads?',
            'Yes. Go to your dashboard and tap "Change Heads". '
            'The request needs admin approval.'),
          _faqTile(context, 'How is my credit balance calculated?',
            'When you pay more than your required amount, the excess becomes credit. '
            'This credit can cover future months automatically.'),
        ],
      ),
    );
  }

  Widget _faqTile(BuildContext context, String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(answer, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      ],
    );
  }
}
