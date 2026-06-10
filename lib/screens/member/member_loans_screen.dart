import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/loan.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/models/payment_request.dart' show PaymentType;
import '../../providers/auth_provider.dart';
import 'member_pay_screen.dart';

final memberLoansProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) {
  final repo = LoanRepository();
  return repo.watchMemberActiveLoans(memberId);
});

final memberAllLoansProvider = StreamProvider.family<List<Loan>, String>((ref, memberId) {
  final repo = LoanRepository();
  return repo.watchLoansByMember(memberId);
});

class MemberLoansScreen extends ConsumerWidget {
  const MemberLoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(currentUserProvider);
    final user = auth.state;
    final memberId = user?.memberId;
    final colorScheme = Theme.of(context).colorScheme;

    if (memberId == null) {
      return const Scaffold(body: Center(child: Text('Member ID not found')));
    }

    final activeLoansAsync = ref.watch(memberLoansProvider(memberId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Loans'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(memberLoansProvider(memberId));
          ref.invalidate(memberAllLoansProvider(memberId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Loans',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              activeLoansAsync.when(
                data: (loans) => loans.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.check_circle, size: 48, color: AppColors.success),
                                const SizedBox(height: 12),
                                Text('No active loans',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('You have no outstanding loans.',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: loans.map((loanData) {
                          final loan = loanData['loan'] as Loan;
                          final remainingBalance = loanData['remainingBalance'] as double;
                          final totalDue = loan.principal + (loan.principal * loan.interestRate);
                          final progress = totalDue > 0 ? ((totalDue - remainingBalance) / totalDue).clamp(0.0, 1.0) : 0.0;
                          final now = DateTime.now();
                          final isOverdue = loan.dueDate.isBefore(now);
                          final daysDiff = now.difference(loan.dueDate).inDays;

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
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Loan #${loan.id!.length > 5 ? loan.id!.substring(0, 5) : loan.id}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          Text('${(loan.interestRate * 100).toStringAsFixed(0)}% interest',
                                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(CurrencyFormatter.format(remainingBalance),
                                            style: TextStyle(color: isOverdue ? AppColors.error : AppColors.warning, fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text(isOverdue ? '$daysDiff days overdue' : 'Balance due',
                                            style: TextStyle(color: isOverdue ? AppColors.error : colorScheme.onSurfaceVariant, fontSize: 10)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: colorScheme.surfaceContainerHighest,
                                          color: isOverdue ? AppColors.error : AppColors.warning,
                                          minHeight: 6,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${(progress * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('Principal: ${CurrencyFormatter.format(loan.principal)}',
                                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                                      ),
                                      Text('Due: ${DateFormat('M/d/yyyy').format(loan.dueDate)}',
                                        style: TextStyle(color: isOverdue ? AppColors.error : colorScheme.onSurfaceVariant, fontSize: 12)),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => MemberPayScreen(loanId: loan.id, paymentType: PaymentType.loan),
                                        ));
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.warning, foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Repay Loan'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, size: 40, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('Error loading loans', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _RepaidLoansSection(memberId: memberId),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepaidLoansSection extends ConsumerWidget {
  final String memberId;
  const _RepaidLoansSection({required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLoansAsync = ref.watch(memberAllLoansProvider(memberId));
    final colorScheme = Theme.of(context).colorScheme;

    return allLoansAsync.when(
      data: (loans) {
        final repaid = loans.where((l) => l.isFullyRepaid).toList();
        if (repaid.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repaid Loans',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...repaid.map((loan) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.success,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
                title: Text('Loan #${loan.id!.length > 5 ? loan.id!.substring(0, 5) : loan.id}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Principal: ${CurrencyFormatter.format(loan.principal)} • ${(loan.interestRate * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PAID',
                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
            )),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}