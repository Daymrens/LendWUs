import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirestoreException;
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../data/repositories/payment_request_repository.dart';
import '../../data/repositories/loan_request_repository.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/loan_request.dart';
import '../modals/member_loan_request_modal.dart';

final memberPaymentRequestsProvider = StreamProvider.family<List<PaymentRequest>, String>((ref, memberId) {
  final repo = PaymentRequestRepository();
  return repo.watchMemberPaymentRequests(memberId);
});

final memberLoanRequestsProvider = StreamProvider.family<List<LoanRequest>, String>((ref, memberId) {
  final repo = LoanRequestRepository();
  return repo.watchMemberLoanRequests(memberId);
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
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Requests'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Payments'),
              Tab(text: 'Loans'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PaymentRequestsTab(memberId: memberId),
            _LoanRequestsTab(memberId: memberId),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const MemberLoanRequestModal(),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Request Loan'),
        ),
      ),
    );
  }
}

class _PaymentRequestsTab extends ConsumerWidget {
  final String memberId;

  const _PaymentRequestsTab({required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(memberPaymentRequestsProvider(memberId));

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No payment requests'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(memberPaymentRequestsProvider(memberId));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
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
                            CurrencyFormatter.format(request.amount),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildStatusBadge(request.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Submitted: ${DateFormatter.format(request.requestDate)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      if (request.approvedDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Processed: ${DateFormatter.format(request.approvedDate!)}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                      if (request.notes != null && request.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Note: ${request.notes}',
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildStatusBadge(PaymentStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case PaymentStatus.pending:
        color = AppColors.warning;
        text = 'PENDING';
        break;
      case PaymentStatus.approved:
        color = AppColors.success;
        text = 'APPROVED';
        break;
      case PaymentStatus.rejected:
        color = AppColors.error;
        text = 'REJECTED';
        break;
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
}

class _LoanRequestsTab extends ConsumerWidget {
  final String memberId;

  const _LoanRequestsTab({required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(memberLoanRequestsProvider(memberId));

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No loan requests'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(memberLoanRequestsProvider(memberId));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
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
                              Text(
                                CurrencyFormatter.format(request.amount),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${request.interestRate}% interest',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                          _buildStatusBadge(request.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Due: ${DateFormatter.format(request.dueDate)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requested: ${DateFormatter.format(request.requestedAt)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      if (request.processedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Processed: ${DateFormatter.format(request.processedAt!)}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                      if (request.notes != null && request.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Note: ${request.notes}',
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildStatusBadge(LoanRequestStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case LoanRequestStatus.pending:
        color = AppColors.warning;
        text = 'PENDING';
        break;
      case LoanRequestStatus.approved:
        color = AppColors.info;
        text = 'APPROVED';
        break;
      case LoanRequestStatus.rejected:
        color = AppColors.error;
        text = 'REJECTED';
        break;
      case LoanRequestStatus.disbursed:
        color = AppColors.success;
        text = 'DISBURSED';
        break;
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
}
