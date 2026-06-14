import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/member.dart';
import '../../data/models/contribution.dart';
import '../../data/models/loan.dart';
import '../../data/models/repayment.dart';
import '../../data/models/payment_request.dart';
import '../../providers/members_provider.dart';
import '../../providers/loans_provider.dart';
import '../modals/add_member_modal.dart';

class AdminMemberProfileScreen extends ConsumerStatefulWidget {
  final String memberId;

  const AdminMemberProfileScreen({super.key, required this.memberId});

  @override
  ConsumerState<AdminMemberProfileScreen> createState() => _AdminMemberProfileScreenState();
}

class _AdminMemberProfileScreenState extends ConsumerState<AdminMemberProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(memberByIdProvider(widget.memberId));
    final contributionsAsync = ref.watch(contributionsStreamProvider);
    final loansAsync = ref.watch(loansStreamProvider);
    final repaymentsAsync = ref.watch(repaymentsStreamProvider);
    final paymentsAsync = ref.watch(paymentRequestsStreamProvider);

    final streamErrors = <String>[];
    if (contributionsAsync.hasError) streamErrors.add('contributions');
    if (loansAsync.hasError) streamErrors.add('loans');
    if (repaymentsAsync.hasError) streamErrors.add('repayments');
    if (paymentsAsync.hasError) streamErrors.add('payment requests');

    return memberAsync.when(
      data: (member) {
        if (member == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Member')),
            body: const Center(child: Text('Member not found')),
          );
        }

        final allContribs = [...?contributionsAsync.asData?.value];
        final memberContribs = allContribs.where((c) => c.memberId == widget.memberId).toList();
        final totalContribs = memberContribs.fold<double>(0.0, (s, c) => s + c.amount);

        final allLoans = [...?loansAsync.asData?.value];
        final memberLoans = allLoans.where((l) => l.memberId == widget.memberId).toList();
        final totalLoans = memberLoans.fold<double>(0.0, (s, l) => s + l.principal);
        final activeLoans = memberLoans.where((l) => !l.isFullyRepaid).length;
        final overdueLoans = memberLoans.where((l) => !l.isFullyRepaid && l.dueDate.isBefore(DateTime.now())).length;

        final loanIds = memberLoans.map((l) => l.id).whereType<String>().toSet();
        final allRepayments = [...?repaymentsAsync.asData?.value];
        final memberRepayments = allRepayments.where((r) => loanIds.contains(r.loanId)).toList();
        final totalRepaid = memberRepayments.fold<double>(0.0, (s, r) => s + r.amountPaid);

        final allPayments = [...?paymentsAsync.asData?.value];
        final memberPayments = allPayments.where((p) => p.memberId == widget.memberId).toList();

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(member.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => AddMemberModal(existingMember: member),
                  );
                },
                tooltip: 'Edit member',
              ),
            ],
          ),
          body: Column(
            children: [
              _MemberHeader(member: member),
              if (streamErrors.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withAlpha(128)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: AppColors.warning, size: 16),
                      const Gap(8),
                      Expanded(
                        child: Text('Error loading ${streamErrors.join(', ')}',
                          style: const TextStyle(color: AppColors.warning, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              _StatsRow(
                totalContributions: totalContribs,
                totalLoans: totalLoans,
                activeLoans: activeLoans,
                totalRepaid: totalRepaid,
                overdueLoans: overdueLoans,
              ),
              const Gap(8),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Contributions'),
                  Tab(text: 'Loans'),
                  Tab(text: 'Payments'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ContributionsTab(contributions: memberContribs),
                    _LoansTab(loans: memberLoans, repayments: memberRepayments),
                    _PaymentsTab(payments: memberPayments),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Member Profile')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Member Profile')),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _MemberHeader extends StatelessWidget {
  final Member member;

  const _MemberHeader({required this.member});

  @override
  Widget build(BuildContext context) {
    final statusColor = member.isActive ? AppColors.primary : AppColors.textMuted;
    final joinedDate = DateFormat('MMM d, yyyy').format(member.joinedAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceAlt, width: 1)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withAlpha(30),
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 28),
            ),
          ),
          const Gap(12),
          Text(member.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Gap(4),
          if (member.displayId.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                member.displayId,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted, fontFamily: 'monospace'),
              ),
            ),
          const Gap(8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (member.isActive ? AppColors.primary : AppColors.textMuted).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  member.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              if (member.linkedEmail != null) ...[
                const Gap(12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.email, size: 14, color: AppColors.textMuted),
                    const Gap(4),
                    Text(member.linkedEmail!, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ],
          ),
          const Gap(6),
          Text('Joined $joinedDate', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const Gap(12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _infoChip('Heads', '${member.headsCount}'),
              _infoChip('Per Head', CurrencyFormatter.format(member.amountPerHead)),
              _infoChip('Required', CurrencyFormatter.format(member.totalRequired)),
              if (member.balance > 0)
                _infoChip('Balance', CurrencyFormatter.format(member.balance)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final double totalContributions;
  final double totalLoans;
  final int activeLoans;
  final double totalRepaid;
  final int overdueLoans;

  const _StatsRow({
    required this.totalContributions,
    required this.totalLoans,
    required this.activeLoans,
    required this.totalRepaid,
    this.overdueLoans = 0,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = overdueLoans > 0
        ? AppColors.error
        : activeLoans > 0
            ? AppColors.warning
            : AppColors.textMuted;
    final activeValue = overdueLoans > 0
        ? '$overdueLoans overdue'
        : '$activeLoans';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(child: _StatTile(label: 'Total Contributions', value: CurrencyFormatter.format(totalContributions), icon: Icons.payments, color: AppColors.primary)),
          const Gap(8),
          Expanded(child: _StatTile(label: 'Total Loans', value: CurrencyFormatter.format(totalLoans), icon: Icons.account_balance, color: AppColors.warning)),
          const Gap(8),
          Expanded(child: _StatTile(label: 'Active Loans', value: activeValue, icon: Icons.trending_up, color: activeColor)),
          const Gap(8),
          Expanded(child: _StatTile(label: 'Repayments', value: CurrencyFormatter.format(totalRepaid), icon: Icons.receipt, color: AppColors.secondary)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 9), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ContributionsTab extends StatelessWidget {
  final List<Contribution> contributions;

  const _ContributionsTab({required this.contributions});

  @override
  Widget build(BuildContext context) {
    if (contributions.isEmpty) {
      return Center(child: Text('No contributions yet', style: TextStyle(color: AppColors.textMuted)));
    }

    final sorted = List<Contribution>.from(contributions)..sort((a, b) => b.date.compareTo(a.date));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = sorted[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withAlpha(25),
            child: Text('${c.month}/${c.year % 100}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          title: Text(CurrencyFormatter.format(c.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(DateFormat('MMM d, yyyy').format(c.date), style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          trailing: c.notes != null && c.notes!.isNotEmpty
              ? Tooltip(message: c.notes!, child: Icon(Icons.info_outline, size: 18, color: AppColors.textMuted))
              : null,
        );
      },
    );
  }
}

class _LoansTab extends StatelessWidget {
  final List<Loan> loans;
  final List<Repayment> repayments;

  const _LoansTab({required this.loans, required this.repayments});

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return Center(child: Text('No loans yet', style: TextStyle(color: AppColors.textMuted)));
    }

    final sorted = List<Loan>.from(loans)..sort((a, b) => b.issuedDate.compareTo(a.issuedDate));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final loan = sorted[index];
        final isOverdue = !loan.isFullyRepaid && loan.dueDate.isBefore(DateTime.now());
        final daysOverdue = isOverdue ? DateTime.now().difference(loan.dueDate).inDays : 0;
        final loanRepayments = repayments.where((r) => r.loanId == loan.id).toList();
        final totalPaid = loanRepayments.fold<double>(0.0, (s, r) => s + r.amountPaid);
        final remaining = (loan.principal + (loan.principal * loan.interestRate)) - totalPaid;

        Color statusColor;
        String statusLabel;
        if (loan.isFullyRepaid) {
          statusColor = AppColors.primary;
          statusLabel = 'Paid';
        } else if (isOverdue) {
          statusColor = AppColors.error;
          statusLabel = '$daysOverdue d overdue';
        } else {
          statusColor = AppColors.warning;
          statusLabel = 'Active';
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: isOverdue
              ? BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.error, width: 3)),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Principal: ${CurrencyFormatter.format(loan.principal)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(4),
              Text('Interest: ${(loan.interestRate * 100).toStringAsFixed(1)}%', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              Text('Issued: ${DateFormat('MMM d, yyyy').format(loan.issuedDate)}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text('Due: ${DateFormat('MMM d, yyyy').format(loan.dueDate)}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              if (!loan.isFullyRepaid)
                Text('Remaining: ${CurrencyFormatter.format(remaining > 0 ? remaining : 0)}',
                  style: TextStyle(color: isOverdue ? AppColors.error : remaining > 0 ? AppColors.warning : AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  final List<PaymentRequest> payments;

  const _PaymentsTab({required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Center(child: Text('No payment requests yet', style: TextStyle(color: AppColors.textMuted)));
    }

    final sorted = List<PaymentRequest>.from(payments)..sort((a, b) => b.requestDate.compareTo(a.requestDate));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = sorted[index];

        Color statusColor;
        String statusLabel;
        switch (p.status) {
          case PaymentStatus.approved:
            statusColor = AppColors.primary;
            statusLabel = 'Approved';
            break;
          case PaymentStatus.rejected:
            statusColor = AppColors.error;
            statusLabel = 'Rejected';
            break;
          default:
            statusColor = AppColors.warning;
            statusLabel = 'Pending';
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: Icon(
            p.type == PaymentType.loan ? Icons.account_balance : Icons.payments,
            color: statusColor, size: 24,
          ),
          title: Text(CurrencyFormatter.format(p.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${DateFormat('MMM d, yyyy').format(p.requestDate)} • ${p.type == PaymentType.loan ? 'Loan' : 'Contribution'}',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}
