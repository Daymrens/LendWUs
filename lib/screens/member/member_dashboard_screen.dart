import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fund_summary_provider.dart';
import '../../data/models/fund_summary.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../data/repositories/loan_repository.dart';

final memberContributionsTotalProvider = FutureProvider.family<double, String>((ref, memberId) async {
  final repo = ContributionRepository();
  return await repo.getMemberTotalContributions(memberId);
});

final memberActiveLoansProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final repo = LoanRepository();
  return await repo.getMemberActiveLoans(memberId);
});

class MemberDashboardScreen extends ConsumerWidget {
  const MemberDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(currentUserProvider);
    final user = auth.state;
    final memberId = user?.memberId;
    
    if (memberId == null) {
      return const Scaffold(
        body: Center(child: Text('Member ID not found')),
      );
    }

    final fundSummaryAsync = ref.watch(fundSummaryProvider);
    final memberContributionsAsync = ref.watch(memberContributionsTotalProvider(memberId));
    final memberLoansAsync = ref.watch(memberActiveLoansProvider(memberId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(currentUserProvider).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(fundSummaryProvider);
          ref.invalidate(memberContributionsTotalProvider(memberId));
          ref.invalidate(memberActiveLoansProvider(memberId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${user?.username}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              fundSummaryAsync.when(
                data: (summary) => _buildFundOverviewCard(context, summary),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading fund summary'),
              ),
              
              const SizedBox(height: 16),
              
              memberContributionsAsync.when(
                data: (total) => _buildMyContributionsCard(context, total),
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const Text('Error loading contributions'),
              ),
              
              const SizedBox(height: 16),
              
              memberLoansAsync.when(
                data: (loans) => _buildMyLoansCard(context, loans),
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const Text('Error loading loans'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFundOverviewCard(BuildContext context, FundSummary fundSummary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fund Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  'Total Balance',
                  CurrencyFormatter.format(fundSummary.fundBalance),
                  AppColors.primary,
                ),
                _buildStatItem(
                  context,
                  'Available',
                  CurrencyFormatter.format(fundSummary.availableToLoan),
                  AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyContributionsCard(BuildContext context, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Contributions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                CurrencyFormatter.format(total),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyLoansCard(BuildContext context, List<Map<String, dynamic>> loans) {
    final totalOutstanding = loans.fold<double>(
      0,
      (sum, loan) => sum + (loan['remainingBalance'] as double),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Active Loans',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (loans.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No active loans',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        'Active Loans',
                        loans.length.toString(),
                        AppColors.warning,
                      ),
                      _buildStatItem(
                        context,
                        'Outstanding',
                        CurrencyFormatter.format(totalOutstanding),
                        AppColors.error,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
