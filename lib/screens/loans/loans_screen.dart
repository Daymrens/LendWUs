import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/loan.dart';
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
  int _sortIndex = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _sortOptions = ['Newest', 'Oldest', 'Amount', 'Overdue first'];

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
    final overdueCount = ref.watch(overdueLoansCountProvider);

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
          PopupMenuButton<int>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            color: AppColors.surfaceAlt,
            onSelected: (v) => setState(() => _sortIndex = v),
            itemBuilder: (_) => _sortOptions.asMap().entries.map((e) {
              return PopupMenuItem(
                value: e.key,
                child: Row(
                  children: [
                    Icon(e.key == _sortIndex ? Icons.check : Icons.check_box_outline_blank, size: 16, color: AppColors.primary),
                    const Gap(8),
                    Text(e.value),
                  ],
                ),
              );
            }).toList(),
          ),
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
          _buildStatsSummary(overdueCount),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by member name...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(activeLoansStreamProvider);
                    ref.invalidate(membersStreamProvider);
                    ref.invalidate(repaymentsStreamProvider);
                  },
                  child: _buildActiveLoans(),
                ),
                RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(loansStreamProvider);
                    ref.invalidate(membersStreamProvider);
                    ref.invalidate(repaymentsStreamProvider);
                  },
                  child: _buildCompletedLoans(),
                ),
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

  Widget _buildStatsSummary(int overdueCount) {
    final loansAsync = ref.watch(loansStreamProvider);
    final repaymentsAsync = ref.watch(repaymentsStreamProvider);
    final loans = [...?loansAsync.asData?.value];
    final repayments = [...?repaymentsAsync.asData?.value];
    if (loansAsync.isLoading || repaymentsAsync.isLoading) return const SizedBox.shrink();

    final activeLoans = loans.where((l) => !l.isFullyRepaid).length;
    final completedLoans = loans.where((l) => l.isFullyRepaid).length;
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

    final repaymentRate = totalLoaned > 0 ? (totalRepaid / totalLoaned * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            children: [
              _statItem('$activeLoans Active', '$overdueCount Overdue', AppColors.warning, overdueCount > 0 ? AppColors.error : AppColors.textMuted),
              const Spacer(),
              _statItem(CurrencyFormatter.format(totalLoaned), 'Total Loaned', AppColors.primary, AppColors.primary),
              const Spacer(),
              _statItem(CurrencyFormatter.format(outstandingBalance), 'Outstanding', AppColors.warning, AppColors.warning),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              _miniChip('$completedLoans Paid', AppColors.primary),
              const Gap(6),
              _miniChip('$repaymentRate% repaid', AppColors.secondary),
              const Gap(6),
              _miniChip('${loans.length} Total', AppColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String main, String sub, Color mainColor, Color subColor) {
    return Column(
      children: [
        Text(main, style: TextStyle(color: mainColor, fontSize: 15, fontWeight: FontWeight.bold)),
        Text(sub, style: TextStyle(color: subColor, fontSize: 10)),
      ],
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildActiveLoans() {
    final loansAsync = ref.watch(activeLoansStreamProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    final repaymentsAsync = ref.watch(repaymentsStreamProvider);
    if (loansAsync.isLoading || membersAsync.isLoading || repaymentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    var loans = [...?loansAsync.asData?.value];
    final members = [...?membersAsync.asData?.value];
    final repayments = [...?repaymentsAsync.asData?.value];
    final memberMap = {for (var m in members) m.id: m.name};

    if (_searchQuery.isNotEmpty) {
      loans = loans.where((l) {
        final name = memberMap[l.memberId] ?? '';
        return name.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    _applySort(loans);

    if (loans.isEmpty) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance, size: 64, color: AppColors.textMuted),
              Gap(16),
              Text('No active loans', style: TextStyle(fontSize: 18, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        final memberName = memberMap[loan.memberId] ?? 'Unknown';
        final now = DateTime.now();
        final isOverdue = loan.dueDate.isBefore(now) && !loan.isFullyRepaid;
        final daysDiff = now.difference(loan.dueDate).inDays;

        final loanRepayments = repayments.where((r) => r.loanId == loan.id);
        final totalRepaid = loanRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
        final totalDue = loan.principal + (loan.principal * loan.interestRate);
        final remaining = totalDue - totalRepaid;
        final progress = totalDue > 0 ? (totalRepaid / totalDue).clamp(0.0, 1.0) : 0.0;
        final repayCount = loanRepayments.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
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
                    radius: 18,
                    backgroundColor: isOverdue ? AppColors.warning.withAlpha(51) : AppColors.secondary.withAlpha(51),
                    child: Text(memberName[0].toUpperCase(),
                      style: TextStyle(color: isOverdue ? AppColors.warning : AppColors.secondary, fontWeight: FontWeight.bold)),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Loan #${loan.id?.substring(0, 4) ?? ''}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.warning.withAlpha(51), borderRadius: BorderRadius.circular(8)),
                      child: Text('${daysDiff}d overdue', style: const TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.secondary.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                      child: Text('${-daysDiff}d left', style: const TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const Gap(12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _loanField('Principal', CurrencyFormatter.format(loan.principal)),
                  _loanField('Interest', '${(loan.interestRate * 100).toStringAsFixed(1)}%'),
                  _loanField('Remaining', CurrencyFormatter.format(remaining), AppColors.warning),
                ],
              ),
              const Gap(10),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.surfaceAlt,
                      color: isOverdue ? AppColors.warning : AppColors.secondary,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Gap(8),
                  Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
              const Gap(6),
              Row(
                children: [
                  const Icon(Icons.payment, size: 12, color: AppColors.textMuted),
                  const Gap(4),
                  Text('$repayCount payments · Due ${loan.dueDate.day}/${loan.dueDate.month}/${loan.dueDate.year}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loanField(String label, String value, [Color? valueColor]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildCompletedLoans() {
    final loansAsync = ref.watch(loansStreamProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    final repaymentsAsync = ref.watch(repaymentsStreamProvider);
    if (loansAsync.isLoading || membersAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    var allLoans = [...?loansAsync.asData?.value];
    final members = [...?membersAsync.asData?.value];
    final repayments = [...?repaymentsAsync.asData?.value];
    final memberMap = {for (var m in members) m.id: m.name};

    if (_searchQuery.isNotEmpty) {
      allLoans = allLoans.where((l) {
        final name = memberMap[l.memberId] ?? '';
        return name.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    _applySort(allLoans);
    final completedLoans = allLoans.where((l) => l.isFullyRepaid).toList();

    if (completedLoans.isEmpty) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: AppColors.textMuted),
              Gap(16),
              Text('No completed loans yet', style: TextStyle(fontSize: 18, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedLoans.length,
      itemBuilder: (context, index) {
        final loan = completedLoans[index];
        final memberName = memberMap[loan.memberId] ?? 'Unknown';
        final loanRepayments = repayments.where((r) => r.loanId == loan.id);
        final totalRepaid = loanRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
        final interestPaid = totalRepaid - loan.principal;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withAlpha(51),
                child: const Icon(Icons.check, color: AppColors.primary, size: 18),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${CurrencyFormatter.format(loan.principal)} @ ${(loan.interestRate * 100).toStringAsFixed(0)}% · ${loanRepayments.length} payments',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format(totalRepaid), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('+${CurrencyFormatter.format(interestPaid)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _applySort(List<Loan> loans) {
    switch (_sortIndex) {
      case 1:
        loans.sort((a, b) => a.issuedDate.compareTo(b.issuedDate));
        break;
      case 2:
        loans.sort((a, b) => b.principal.compareTo(a.principal));
        break;
      case 3:
        loans.sort((a, b) {
          final aOverdue = a.dueDate.isBefore(DateTime.now()) && !a.isFullyRepaid;
          final bOverdue = b.dueDate.isBefore(DateTime.now()) && !b.isFullyRepaid;
          if (aOverdue && !bOverdue) return -1;
          if (!aOverdue && bOverdue) return 1;
          return b.issuedDate.compareTo(a.issuedDate);
        });
        break;
      default:
        loans.sort((a, b) => b.issuedDate.compareTo(a.issuedDate));
    }
  }
}
