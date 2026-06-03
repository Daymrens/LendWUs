import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../providers/loans_provider.dart';
import '../../providers/members_provider.dart';
import '../modals/issue_loan_modal.dart';
import '../modals/record_repayment_modal.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const IssueLoanModal(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsSummary(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveLoans(),
                _buildCompletedLoans(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const RecordRepaymentModal(),
          );
        },
        backgroundColor: AppColors.warning,
        icon: const Icon(Icons.payment),
        label: const Text('Record Payment'),
      ),
    );
  }

  Widget _buildStatsSummary() {
    return FutureBuilder(
      future: Future.wait([
        ref.read(loanRepositoryProvider).getAllLoans(),
        ref.read(loanRepositoryProvider).getAllRepayments(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final loans = snapshot.data![0] as List;
        final repayments = snapshot.data![1] as List;

        final activeLoans = loans.where((l) => !l.isFullyRepaid).length;
        final totalLoaned = loans.fold<double>(0.0, (sum, l) => sum + l.principal);
        final totalRepaid = repayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);

        double outstandingBalance = 0.0;
        for (var loan in loans) {
          if (!loan.isFullyRepaid) {
            final loanRepayments = repayments.where((r) => r.loanId == loan.id);
            final totalLoanRepaid = loanRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
            final totalDue = loan.principal + (loan.principal * loan.interestRate);
            outstandingBalance += (totalDue - totalLoanRepaid);
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Active', '$activeLoans', AppColors.secondary),
              ),
              Expanded(
                child: _buildSummaryItem('Total Loaned', CurrencyFormatter.format(totalLoaned), AppColors.primary),
              ),
              Expanded(
                child: _buildSummaryItem('Outstanding', CurrencyFormatter.format(outstandingBalance), AppColors.warning),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Gap(4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveLoans() {
    return FutureBuilder(
      future: Future.wait([
        ref.read(loanRepositoryProvider).getActiveLoans(),
        ref.read(memberRepositoryProvider).getAllMembers(),
        ref.read(loanRepositoryProvider).getAllRepayments(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final loans = snapshot.data![0] as List;
        final members = snapshot.data![1] as List;
        final repayments = snapshot.data![2] as List;

        if (loans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance, size: 64, color: AppColors.textMuted),
                const Gap(16),
                Text(
                  'No active loans',
                  style: TextStyle(fontSize: 18, color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            final member = members.firstWhere((m) => m.id == loan.memberId, orElse: () => null);
            
            final loanRepayments = repayments.where((r) => r.loanId == loan.id);
            final totalRepaid = loanRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
            final totalDue = loan.principal + (loan.principal * loan.interestRate);
            final remaining = totalDue - totalRepaid;
            final progress = totalDue > 0 ? (totalRepaid / totalDue).clamp(0.0, 1.0) : 0.0;

            final isOverdue = loan.dueDate.isBefore(DateTime.now()) && !loan.isFullyRepaid;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: isOverdue ? Border.all(color: AppColors.warning, width: 2) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.secondary.withOpacity(0.2),
                        child: Text(
                          member?.name[0].toUpperCase() ?? 'L',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member?.name ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Loan #${loan.id}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'OVERDUE',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Principal',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          Text(
                            CurrencyFormatter.format(loan.principal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Interest',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          Text(
                            '${(loan.interestRate * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Remaining',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          Text(
                            CurrencyFormatter.format(remaining),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Gap(12),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceAlt,
                    color: AppColors.secondary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const Gap(8),
                  Text(
                    'Due: ${loan.dueDate.day}/${loan.dueDate.month}/${loan.dueDate.year}',
                    style: TextStyle(
                      color: isOverdue ? AppColors.warning : AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedLoans() {
    return FutureBuilder(
      future: Future.wait([
        ref.read(loanRepositoryProvider).getAllLoans(),
        ref.read(memberRepositoryProvider).getAllMembers(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allLoans = snapshot.data![0] as List;
        final members = snapshot.data![1] as List;
        final completedLoans = allLoans.where((l) => l.isFullyRepaid).toList();

        if (completedLoans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: AppColors.textMuted),
                const Gap(16),
                Text(
                  'No completed loans yet',
                  style: TextStyle(fontSize: 18, color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completedLoans.length,
          itemBuilder: (context, index) {
            final loan = completedLoans[index];
            final member = members.firstWhere((m) => m.id == loan.memberId, orElse: () => null);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: const Icon(Icons.check, color: AppColors.primary),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member?.name ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Principal: ${CurrencyFormatter.format(loan.principal)} • ${(loan.interestRate * 100).toStringAsFixed(1)}% interest',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PAID',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
