import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/contribution_repository.dart';

final complianceDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final memberRepo = MemberRepository();
  final loanRepo = LoanRepository();
  final contribRepo = ContributionRepository();

  final members = await memberRepo.getAllMembers();
  final activeMembers = members.where((m) => m.isActive).toList();
  final loans = await loanRepo.getAllLoans();
  final activeLoans = loans.where((l) => !l.isFullyRepaid).toList();
  final contributions = await contribRepo.getAllContributions();
  final repayments = await loanRepo.getAllRepayments();

  final totalContributions = contributions.fold<double>(0, (s, c) => s + c.amount);
  final totalLoansIssued = loans.fold<double>(0, (s, l) => s + l.principal);
  final totalRepaid = repayments.fold<double>(0, (s, r) => s + r.amountPaid);
  final outstandingBalance = totalLoansIssued - totalRepaid;

  return {
    'totalMembers': members.length,
    'activeMembers': activeMembers.length,
    'totalLoans': loans.length,
    'activeLoans': activeLoans.length,
    'totalContributions': totalContributions,
    'totalLoansIssued': totalLoansIssued,
    'totalRepaid': totalRepaid,
    'outstandingBalance': outstandingBalance,
    'fundBalance': totalContributions - totalLoansIssued + totalRepaid,
  };
});

class ComplianceReportsScreen extends ConsumerWidget {
  const ComplianceReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(complianceDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Compliance Reports')),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section('Membership', [
                _card('Total Members', '${data['totalMembers']}', Icons.people, AppColors.primary),
                _card('Active Members', '${data['activeMembers']}', Icons.person, AppColors.success),
              ]),
              const Gap(16),
              _section('Loans', [
                _card('Total Loans', '${data['totalLoans']}', Icons.account_balance, AppColors.warning),
                _card('Active Loans', '${data['activeLoans']}', Icons.pending, AppColors.error),
              ]),
              const Gap(16),
              _section('Financial Summary', [
                _card('Total Contributions', CurrencyFormatter.format(data['totalContributions'] as double), Icons.payments, AppColors.success),
                _card('Total Loans Issued', CurrencyFormatter.format(data['totalLoansIssued'] as double), Icons.money_off, AppColors.error),
                _card('Total Repaid', CurrencyFormatter.format(data['totalRepaid'] as double), Icons.assignment_return, AppColors.primary),
                _card('Outstanding Balance', CurrencyFormatter.format(data['outstandingBalance'] as double), Icons.balance, AppColors.warning),
                _card('Fund Balance', CurrencyFormatter.format(data['fundBalance'] as double), Icons.account_balance_wallet, AppColors.success),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Gap(8),
        ...children,
      ],
    );
  }

  Widget _card(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const Gap(16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }
}
