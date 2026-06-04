import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/returns_provider.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/models/payment_request.dart';
import 'member_pay_screen.dart';

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

    final memberContributionsAsync = ref.watch(memberContributionsTotalProvider(memberId));
    final memberLoansAsync = ref.watch(memberActiveLoansProvider(memberId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
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
              
              const SizedBox(height: 24),
              
              Text(
                'My Active Loans',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              memberLoansAsync.when(
                data: (loans) => _buildLoansList(context, loans),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading loans'),
              ),
              
              const SizedBox(height: 24),
              _MemberReturnsSection(),
            ],
          ),
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
                    color: AppColors.success.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
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

  Widget _buildLoansList(BuildContext context, List<Map<String, dynamic>> loans) {
    if (loans.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('No active loans'),
          ),
        ),
      );
    }

    return Column(
      children: loans.map((loanData) {
        final loan = loanData['loan'];
        final remainingBalance = loanData['remainingBalance'] as double;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Loan #${loan.id.substring(0, 5)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      CurrencyFormatter.format(remainingBalance),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Principal: ${CurrencyFormatter.format(loan.principal)}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const Text(
                      'Balance Due',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Interest: ${CurrencyFormatter.format(loan.principal * loan.interestRate)}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MemberPayScreen(
                            loanId: loan.id,
                            paymentType: PaymentType.loan,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Repay Loan'),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MemberReturnsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(returnsInfoProvider);
    final user = ref.watch(currentUserProvider).state;
    final memberId = user?.memberId;

    return returnsAsync.when(
      data: (info) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'End of Year Returns',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Returns Pool',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.format(info.totalReturns),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Per Head Share',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.format(info.perHeadShare),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Heads', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        Text(
                          '${info.totalHeads}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}
