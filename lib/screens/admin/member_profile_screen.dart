import 'dart:convert';
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
                    _ContributionsTab(
                      contributions: memberContribs,
                      onTap: _showContributionDetail,
                    ),
                    _LoansTab(
                      loans: memberLoans,
                      repayments: memberRepayments,
                      onTap: _showLoanDetail,
                    ),
                    _PaymentsTab(
                      payments: memberPayments,
                      onTap: _showPaymentDetail,
                    ),
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

  void _showContributionDetail(Contribution c) {
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final timestamp = '${c.date.year}-${c.date.month.toString().padLeft(2, '0')}-${c.date.day.toString().padLeft(2, '0')} '
          '${c.date.hour.toString().padLeft(2, '0')}:${c.date.minute.toString().padLeft(2, '0')}:${c.date.second.toString().padLeft(2, '0')}';
      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 20),
              Text('Contribution Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _detailRow('Amount', CurrencyFormatter.format(c.amount)),
              _detailRow('Period', '${months[c.month - 1]} ${c.year}'),
              _detailRow('Timestamp', timestamp),
              _detailRow('Transaction ID', c.id ?? 'N/A'),
              if (c.notes != null && c.notes!.isNotEmpty)
                _detailRow('Notes', c.notes!),
              if (c.createdBy != null)
                _detailRow('Created By', c.createdBy == 'member' ? 'Member (via request)' : 'Admin'),
              if (c.receiptUrl != null && c.receiptUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _viewReceipt(context, c.receiptUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: c.receiptUrl!.startsWith('data:image')
                      ? Image.memory(base64Decode(c.receiptUrl!.split(',').last),
                          height: 200, width: double.infinity, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text('Failed to load receipt'))
                      : Image.network(c.receiptUrl!,
                          height: 200, width: double.infinity, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text('Failed to load receipt')),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    },
  );
}

void _showLoanDetail(Loan loan, List<Repayment> loanRepayments) {
  final totalPaid = loanRepayments.fold<double>(0.0, (s, r) => s + r.amountPaid);
  final totalDue = loan.principal + (loan.principal * loan.interestRate);
  final remaining = totalDue - totalPaid;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: scrollController,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 20),
            Text('Loan Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _detailRow('Principal', CurrencyFormatter.format(loan.principal)),
            _detailRow('Interest Rate', '${(loan.interestRate * 100).toStringAsFixed(1)}%'),
            _detailRow('Total Due', CurrencyFormatter.format(totalDue)),
            _detailRow('Issued', DateFormat('MMM d, yyyy').format(loan.issuedDate)),
            _detailRow('Due', DateFormat('MMM d, yyyy').format(loan.dueDate)),
            _detailRow('Total Paid', CurrencyFormatter.format(totalPaid)),
            _detailRow('Remaining', CurrencyFormatter.format(remaining > 0 ? remaining : 0)),
            _detailRow('Status', loan.isFullyRepaid ? 'Paid' : remaining > 0 ? 'Active' : 'Paid'),
            if (loanRepayments.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Repayments', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...loanRepayments.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.receipt, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(CurrencyFormatter.format(r.amountPaid), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(DateFormat('MMM d, yyyy').format(r.date), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

void _showPaymentDetail(PaymentRequest p) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final statusStr = p.status == PaymentStatus.approved ? 'Approved'
          : p.status == PaymentStatus.rejected ? 'Rejected' : 'Pending';
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 20),
              Text('Payment Request', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _detailRow('Type', p.type == PaymentType.loan ? 'Loan Repayment' : 'Contribution'),
              _detailRow('Amount', CurrencyFormatter.format(p.amount)),
              _detailRow('Date', DateFormat('MMM d, yyyy').format(p.requestDate)),
              _detailRow('Status', statusStr),
              if (p.notes != null && p.notes!.isNotEmpty)
                _detailRow('Notes', p.notes!),
              if (p.bankConfirmed)
                _detailRow('Bank Confirmed', 'Yes'),
              if (p.receiptUrl != null && p.receiptUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _viewReceipt(context, p.receiptUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: p.receiptUrl!.startsWith('data:image')
                      ? Image.memory(base64Decode(p.receiptUrl!.split(',').last),
                          height: 200, width: double.infinity, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text('Failed to load receipt'))
                      : Image.network(p.receiptUrl!,
                          height: 200, width: double.infinity, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text('Failed to load receipt')),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    },
  );
}

void _viewReceipt(BuildContext context, String receiptUrl) {
  final isBase64 = receiptUrl.startsWith('data:image');

  Widget body;
  if (isBase64) {
    try {
      final bytes = base64Decode(receiptUrl.split(',').last);
      body = Image.memory(bytes, fit: BoxFit.contain,
          errorBuilder: (_, e, __) => Text('Err: $e',
              style: const TextStyle(color: Colors.red, fontSize: 20)));
    } catch (e) {
      body = Text('Decode fail: $e',
          style: const TextStyle(color: Colors.red, fontSize: 20));
    }
  } else {
    body = Image.network(receiptUrl, fit: BoxFit.contain,
        errorBuilder: (_, e, __) => Text('Err: $e',
            style: const TextStyle(color: Colors.red, fontSize: 20)));
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: body),
      ),
    ),
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ),
      ],
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
  final void Function(Contribution) onTap;

  const _ContributionsTab({required this.contributions, required this.onTap});

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
            onTap: () => onTap(c),
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
  final void Function(Loan, List<Repayment>) onTap;

  const _LoansTab({required this.loans, required this.repayments, required this.onTap});

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

        return GestureDetector(
          onTap: () => onTap(loan, loanRepayments),
          child: Container(
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
        ),
      );
    },
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  final List<PaymentRequest> payments;
  final void Function(PaymentRequest) onTap;

  const _PaymentsTab({required this.payments, required this.onTap});

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
            onTap: () => onTap(p),
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
