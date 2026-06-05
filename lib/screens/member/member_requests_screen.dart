import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../data/repositories/payment_request_repository.dart';
import '../../data/repositories/loan_request_repository.dart';
import '../../data/repositories/head_change_request_repository.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/loan_request.dart';
import '../../data/models/head_change_request.dart';
import '../modals/member_loan_request_modal.dart';

final memberPaymentRequestsProvider = StreamProvider.family<List<PaymentRequest>, String>((ref, memberId) {
  final repo = PaymentRequestRepository();
  return repo.watchMemberPaymentRequests(memberId);
});

final memberLoanRequestsProvider = StreamProvider.family<List<LoanRequest>, String>((ref, memberId) {
  final repo = LoanRequestRepository();
  return repo.watchMemberLoanRequests(memberId);
});

final memberHeadChangeRequestsProvider = StreamProvider.family<List<HeadChangeRequest>, String>((ref, memberId) {
  final repo = HeadChangeRequestRepository();
  return repo.watchMemberHeadChangeRequests(memberId);
});

class MemberRequestsScreen extends ConsumerWidget {
  const MemberRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).state;
    final memberId = user?.memberId;

    if (memberId == null) {
      return const Scaffold(
        body: Center(child: Text('Member ID not found')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Requests'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Payments'),
              Tab(text: 'Loans'),
              Tab(text: 'Heads'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PaymentRequestsTab(memberId: memberId),
            _LoanRequestsTab(memberId: memberId),
            _HeadChangesTab(memberId: memberId),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const MemberLoanRequestModal(),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Request Loan'),
        ),
      ),
    );
  }
}

class _PaymentRequestsTab extends ConsumerStatefulWidget {
  final String memberId;
  const _PaymentRequestsTab({required this.memberId});

  @override
  ConsumerState<_PaymentRequestsTab> createState() => _PaymentRequestsTabState();
}

class _PaymentRequestsTabState extends ConsumerState<_PaymentRequestsTab> {
  PaymentStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(memberPaymentRequestsProvider(widget.memberId));

    return requestsAsync.when(
      data: (requests) {
        final filtered = _filter != null
            ? requests.where((r) => r.status == _filter).toList()
            : requests;
        final sorted = List<PaymentRequest>.from(filtered)
          ..sort((a, b) => b.requestDate.compareTo(a.requestDate));

        final pending = requests.where((r) => r.status == PaymentStatus.pending).length;
        final approved = requests.where((r) => r.status == PaymentStatus.approved).length;
        final rejected = requests.where((r) => r.status == PaymentStatus.rejected).length;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(memberPaymentRequestsProvider(widget.memberId));
          },
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _filterChip('All', null, pending + approved + rejected),
                    const SizedBox(width: 6),
                    _filterChip('Pending', PaymentStatus.pending, pending),
                    const SizedBox(width: 6),
                    _filterChip('Approved', PaymentStatus.approved, approved),
                    const SizedBox(width: 6),
                    _filterChip('Rejected', PaymentStatus.rejected, rejected),
                  ],
                ),
              ),
              if (sorted.isEmpty)
                const Expanded(child: Center(child: Text('No payment requests')))
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final request = sorted[index];
                      return _buildPaymentCard(request);
                    },
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _filterChip(String label, PaymentStatus? status, int count) {
    final selected = _filter == status;
    return GestureDetector(
      onTap: () => setState(() => _filter = selected ? null : status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 12,
              )),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.2) : AppColors.textMuted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontSize: 10, fontWeight: FontWeight.bold,
                )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(PaymentRequest request) {
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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _statusColor(request.status).withAlpha(30),
                      child: Icon(_statusIcon(request.status),
                        color: _statusColor(request.status), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      CurrencyFormatter.format(request.amount),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                _buildStatusBadge(request.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Submitted ${_formatDate(request.requestDate)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                if (request.type == PaymentType.loan && request.loanId != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.account_balance, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  const Text(
                    'Loan repayment',
                    style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
            if (request.approvedDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Processed ${_formatDate(request.approvedDate!)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
            if (request.notes != null && request.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notes, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        request.notes!,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending: return AppColors.warning;
      case PaymentStatus.approved: return AppColors.success;
      case PaymentStatus.rejected: return AppColors.error;
    }
  }

  IconData _statusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending: return Icons.hourglass_empty;
      case PaymentStatus.approved: return Icons.check_circle;
      case PaymentStatus.rejected: return Icons.cancel;
    }
  }

  Widget _buildStatusBadge(PaymentStatus status) {
    final color = _statusColor(status);
    String text;
    switch (status) {
      case PaymentStatus.pending: text = 'PENDING'; break;
      case PaymentStatus.approved: text = 'APPROVED'; break;
      case PaymentStatus.rejected: text = 'REJECTED'; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _LoanRequestsTab extends ConsumerStatefulWidget {
  final String memberId;
  const _LoanRequestsTab({required this.memberId});

  @override
  ConsumerState<_LoanRequestsTab> createState() => _LoanRequestsTabState();
}

class _LoanRequestsTabState extends ConsumerState<_LoanRequestsTab> {
  LoanRequestStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(memberLoanRequestsProvider(widget.memberId));

    return requestsAsync.when(
      data: (requests) {
        final filtered = _filter != null
            ? requests.where((r) => r.status == _filter).toList()
            : requests;

        final pending = requests.where((r) => r.status == LoanRequestStatus.pending).length;
        final approved = requests.where((r) => r.status == LoanRequestStatus.approved).length;
        final rejected = requests.where((r) => r.status == LoanRequestStatus.rejected).length;
        final disbursed = requests.where((r) => r.status == LoanRequestStatus.disbursed).length;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(memberLoanRequestsProvider(widget.memberId));
          },
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', null, requests.length),
                      const SizedBox(width: 6),
                      _filterChip('Pending', LoanRequestStatus.pending, pending),
                      const SizedBox(width: 6),
                      _filterChip('Approved', LoanRequestStatus.approved, approved),
                      const SizedBox(width: 6),
                      _filterChip('Rejected', LoanRequestStatus.rejected, rejected),
                      const SizedBox(width: 6),
                      _filterChip('Disbursed', LoanRequestStatus.disbursed, disbursed),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                const Expanded(child: Center(child: Text('No loan requests')))
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final request = filtered[index];
                      return _buildLoanCard(request);
                    },
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _filterChip(String label, LoanRequestStatus? status, int count) {
    final selected = _filter == status;
    return GestureDetector(
      onTap: () => setState(() => _filter = selected ? null : status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 12,
              )),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.2) : AppColors.textMuted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontSize: 10, fontWeight: FontWeight.bold,
                )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanCard(LoanRequest request) {
    final isOverdue = request.dueDate.isBefore(DateTime.now()) && request.status == LoanRequestStatus.disbursed;
    final daysDiff = DateTime.now().difference(request.dueDate).inDays;

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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _statusColor(request.status).withAlpha(30),
                      child: Icon(_statusIcon(request.status),
                        color: _statusColor(request.status), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              CurrencyFormatter.format(request.amount),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${request.interestRate}% interest',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(request.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: isOverdue ? AppColors.error : AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Due: ${DateFormatter.format(request.dueDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverdue ? AppColors.error : AppColors.textPrimary,
                    fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isOverdue) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$daysDiff days overdue',
                      style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Requested ${_formatDate(request.requestedAt)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            if (request.processedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Processed ${_formatDate(request.processedAt!)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
            if (request.notes != null && request.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notes, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        request.notes!,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(LoanRequestStatus status) {
    switch (status) {
      case LoanRequestStatus.pending: return AppColors.warning;
      case LoanRequestStatus.approved: return AppColors.info;
      case LoanRequestStatus.rejected: return AppColors.error;
      case LoanRequestStatus.disbursed: return AppColors.success;
    }
  }

  IconData _statusIcon(LoanRequestStatus status) {
    switch (status) {
      case LoanRequestStatus.pending: return Icons.hourglass_empty;
      case LoanRequestStatus.approved: return Icons.thumb_up;
      case LoanRequestStatus.rejected: return Icons.cancel;
      case LoanRequestStatus.disbursed: return Icons.account_balance;
    }
  }

  Widget _buildStatusBadge(LoanRequestStatus status) {
    final color = _statusColor(status);
    String text;
    switch (status) {
      case LoanRequestStatus.pending: text = 'PENDING'; break;
      case LoanRequestStatus.approved: text = 'APPROVED'; break;
      case LoanRequestStatus.rejected: text = 'REJECTED'; break;
      case LoanRequestStatus.disbursed: text = 'DISBURSED'; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _HeadChangesTab extends ConsumerStatefulWidget {
  final String memberId;
  const _HeadChangesTab({required this.memberId});

  @override
  ConsumerState<_HeadChangesTab> createState() => _HeadChangesTabState();
}

class _HeadChangesTabState extends ConsumerState<_HeadChangesTab> {
  HeadChangeStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(memberHeadChangeRequestsProvider(widget.memberId));

    return requestsAsync.when(
      data: (requests) {
        final filtered = _filter != null
            ? requests.where((r) => r.status == _filter).toList()
            : requests;

        final pending = requests.where((r) => r.status == HeadChangeStatus.pending).length;
        final approved = requests.where((r) => r.status == HeadChangeStatus.approved).length;
        final rejected = requests.where((r) => r.status == HeadChangeStatus.rejected).length;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(memberHeadChangeRequestsProvider(widget.memberId));
          },
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _filterChip('All', null, requests.length),
                    const SizedBox(width: 6),
                    _filterChip('Pending', HeadChangeStatus.pending, pending),
                    const SizedBox(width: 6),
                    _filterChip('Approved', HeadChangeStatus.approved, approved),
                    const SizedBox(width: 6),
                    _filterChip('Rejected', HeadChangeStatus.rejected, rejected),
                  ],
                ),
              ),
              if (filtered.isEmpty)
                const Expanded(child: Center(child: Text('No head change requests')))
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final request = filtered[index];
                      return _buildHeadChangeCard(request);
                    },
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _filterChip(String label, HeadChangeStatus? status, int count) {
    final selected = _filter == status;
    return GestureDetector(
      onTap: () => setState(() => _filter = selected ? null : status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 12,
              )),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.2) : AppColors.textMuted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontSize: 10, fontWeight: FontWeight.bold,
                )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadChangeCard(HeadChangeRequest request) {
    final color = _statusColor(request.status);
    final icon = _statusIcon(request.status);

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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: color.withAlpha(30),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${request.currentHeads}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 20,
                                decoration: TextDecoration.lineThrough,
                              )),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18, color: AppColors.textMuted),
                            const SizedBox(width: 8),
                            Text('${request.requestedHeads}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              )),
                          ],
                        ),
                        Text('${request.currentHeads == 1 ? 'head' : 'heads'} → ${request.requestedHeads == 1 ? 'head' : 'heads'}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                _buildStatusBadge(request.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Requested ${_formatDate(request.requestedAt)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            if (request.processedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Processed ${_formatDate(request.processedAt!)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
            if (request.notes != null && request.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notes, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        request.notes!,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(HeadChangeStatus status) {
    switch (status) {
      case HeadChangeStatus.pending: return AppColors.warning;
      case HeadChangeStatus.approved: return AppColors.success;
      case HeadChangeStatus.rejected: return AppColors.error;
    }
  }

  IconData _statusIcon(HeadChangeStatus status) {
    switch (status) {
      case HeadChangeStatus.pending: return Icons.hourglass_empty;
      case HeadChangeStatus.approved: return Icons.check_circle;
      case HeadChangeStatus.rejected: return Icons.cancel;
    }
  }

  Widget _buildStatusBadge(HeadChangeStatus status) {
    final color = _statusColor(status);
    String text;
    switch (status) {
      case HeadChangeStatus.pending: text = 'PENDING'; break;
      case HeadChangeStatus.approved: text = 'APPROVED'; break;
      case HeadChangeStatus.rejected: text = 'REJECTED'; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

