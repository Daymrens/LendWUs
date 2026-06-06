import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/contribution.dart';
import '../../data/models/loan.dart';
import '../../data/models/repayment.dart';
import '../../data/models/member.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/loan_request.dart';
import '../../providers/members_provider.dart';
import '../../providers/loans_provider.dart';
import '../../providers/fund_provider.dart';
import '../../core/firebase/firebase_service.dart';

class AdminDataScreen extends ConsumerStatefulWidget {
  const AdminDataScreen({super.key});

  @override
  ConsumerState<AdminDataScreen> createState() => _AdminDataScreenState();
}

class _AdminDataScreenState extends ConsumerState<AdminDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete ALL contributions, loans, repayments, '
          'members, payment requests, and loan requests. This action CANNOT be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final reconfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'This is your second confirmation. All transaction data will be lost permanently.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Clear Everything'),
          ),
        ],
      ),
    );
    if (reconfirm != true) return;

    try {
      final firestore = FirebaseService.firestore;
      const collections = [
        'contributions',
        'loans',
        'repayments',
        'payment_requests',
        'loan_requests',
        'members',
        'returns',
      ];
      for (final name in collections) {
        final snapshot = await firestore.collection(name).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared successfully')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Contributions'),
            Tab(text: 'Loans'),
            Tab(text: 'Repayments'),
            Tab(text: 'Members'),
            Tab(text: 'Payment Reqs'),
            Tab(text: 'Loan Reqs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ContributionsTab(),
          _LoansTab(),
          _RepaymentsTab(),
          _MembersTab(),
          _PaymentRequestsTab(),
          _LoanRequestsTab(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _clearAllData,
            icon: const Icon(Icons.delete_forever, color: AppColors.error),
            label: const Text('Clear All Data', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContributionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Contribution>>(
      future: ref.read(fundRepositoryProvider).getAllContributions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(child: Text('No contributions'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _DataTile(
              title: CurrencyFormatter.format(item.amount),
              subtitle: '${item.date.day}/${item.date.month}/${item.date.year}',
              trailing: item.memberId,
              onEdit: () => _editContribution(context, ref, item),
              onDelete: () => _deleteContribution(context, ref, item),
            );
          },
        );
      },
    );
  }
}

class _LoansTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Loan>>(
      future: ref.read(loanRepositoryProvider).getAllLoans(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(child: Text('No loans'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final status = item.isFullyRepaid ? 'Paid' : 'Active';
            return _DataTile(
              title: '${CurrencyFormatter.format(item.principal)} ($status)',
              subtitle: 'Issued: ${item.issuedDate.day}/${item.issuedDate.month}/${item.issuedDate.year}',
              trailing: item.memberId,
              onEdit: () => _editLoan(context, ref, item),
              onDelete: () => _deleteLoan(context, ref, item),
            );
          },
        );
      },
    );
  }
}

class _RepaymentsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Repayment>>(
      future: ref.read(loanRepositoryProvider).getAllRepayments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(child: Text('No repayments'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _DataTile(
              title: CurrencyFormatter.format(item.amountPaid),
              subtitle: '${item.date.day}/${item.date.month}/${item.date.year}',
              trailing: 'Loan: ${item.loanId.substring(0, 8)}...',
              onEdit: () => _editRepayment(context, ref, item),
              onDelete: () => _deleteRepayment(context, ref, item),
            );
          },
        );
      },
    );
  }
}

class _MembersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Member>>(
      future: ref.read(memberRepositoryProvider).getAllMembers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(child: Text('No members'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _DataTile(
              title: item.name,
              subtitle: 'Heads: ${item.headsCount} • ${CurrencyFormatter.format(item.amountPerHead)}/head',
              trailing: item.isActive ? 'Active' : 'Inactive',
              onEdit: () => _editMember(context, ref, item),
              onDelete: () => _deleteMember(context, ref, item),
            );
          },
        );
      },
    );
  }
}

class _PaymentRequestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<PaymentRequest>>(
      future: ref.read(paymentRequestRepositoryProvider).getAllPaymentRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(child: Text('No payment requests'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _PaymentRequestDataTile(payment: item, ref: ref);
          },
        );
      },
    );
  }
}

class _PaymentRequestDataTile extends ConsumerWidget {
  final PaymentRequest payment;
  final WidgetRef ref;

  const _PaymentRequestDataTile({required this.payment, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasReceipt = payment.receiptUrl != null || payment.receiptPath != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasReceipt ? () => _showReceipt(context) : null,
        child: Row(
          children: [
            if (hasReceipt)
              Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: payment.receiptUrl != null
                      ? CachedNetworkImage(
                          imageUrl: payment.receiptUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (_, __, ___) => const Icon(Icons.receipt_long, size: 28, color: Colors.grey),
                        )
                      : Image.file(File(payment.receiptPath!), fit: BoxFit.cover),
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_outlined, size: 28, color: Colors.grey),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${CurrencyFormatter.format(payment.amount)}  •  ${payment.type.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Gap(2),
                  Text('${payment.memberId}  •  ${DateFormatter.format(payment.requestDate)}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
                  const Gap(4),
                  Row(
                    children: [
                      _statusChip(payment.status.name, payment.status),
                      const Gap(8),
                      if (hasReceipt)
                        Text('Tap to view receipt',
                          style: TextStyle(color: AppColors.info, fontSize: 10, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18),
              color: colorScheme.error,
              onPressed: () => _deletePaymentRequest(context, ref, payment),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, PaymentStatus status) {
    Color color;
    switch (status) {
      case PaymentStatus.approved:
        color = AppColors.success;
      case PaymentStatus.rejected:
        color = AppColors.error;
      case PaymentStatus.pending:
        color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  void _showReceipt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Receipt  •  ${CurrencyFormatter.format(payment.amount)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (payment.receiptUrl != null)
              CachedNetworkImage(
                imageUrl: payment.receiptUrl!,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Column(
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Failed to load receipt', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else if (payment.receiptPath != null)
              Image.file(File(payment.receiptPath!), fit: BoxFit.contain),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${DateFormatter.format(payment.requestDate)}  •  ${payment.status.name}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanRequestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<LoanRequest>>(
      future: ref.read(loanRequestRepositoryProvider).getAllLoanRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(child: Text('No loan requests'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _DataTile(
              title: '${CurrencyFormatter.format(item.amount)} • ${item.memberName}',
              subtitle: 'Status: ${item.status.name}',
              trailing: item.memberId,
              onEdit: null,
              onDelete: () => _deleteLoanRequest(context, ref, item),
            );
          },
        );
      },
    );
  }
}

class _DataTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _DataTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Gap(2),
                Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Text(trailing, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
          if (onEdit != null) ...[
            const Gap(8),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              color: colorScheme.secondary,
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
          if (onDelete != null) ...[
            const Gap(8),
            IconButton(
              icon: const Icon(Icons.delete, size: 18),
              color: colorScheme.error,
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Edit/Delete helpers ---

Future<void> _editContribution(BuildContext context, WidgetRef ref, Contribution item) async {
  final amountCtl = TextEditingController(text: item.amount.toString());
  final notesCtl = TextEditingController(text: item.notes);
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit Contribution'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountCtl,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const Gap(12),
            TextFormField(
              controller: notesCtl,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, true);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (result == true) {
    item.amount = double.parse(amountCtl.text);
    item.notes = notesCtl.text;
    await ref.read(contributionRepositoryProvider).updateContribution(item);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contribution updated')));
    }
  }
}

Future<void> _deleteContribution(BuildContext context, WidgetRef ref, Contribution item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Contribution?'),
      content: Text('Delete ${CurrencyFormatter.format(item.amount)} contribution?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(contributionRepositoryProvider).deleteContribution(item.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contribution deleted')));
    }
  }
}

Future<void> _editLoan(BuildContext context, WidgetRef ref, Loan item) async {
  final principalCtl = TextEditingController(text: item.principal.toString());
  final interestCtl = TextEditingController(text: (item.interestRate * 100).toString());
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit Loan'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: principalCtl,
              decoration: const InputDecoration(labelText: 'Principal'),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const Gap(12),
            TextFormField(
              controller: interestCtl,
              decoration: const InputDecoration(labelText: 'Interest Rate %'),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, true);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (result == true) {
    item.principal = double.parse(principalCtl.text);
    item.interestRate = double.parse(interestCtl.text) / 100;
    await ref.read(loanRepositoryProvider).updateLoan(item);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan updated')));
    }
  }
}

Future<void> _deleteLoan(BuildContext context, WidgetRef ref, Loan item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Loan?'),
      content: Text('Delete ${CurrencyFormatter.format(item.principal)} loan?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(loanRepositoryProvider).deleteLoan(item.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan deleted')));
    }
  }
}

Future<void> _editRepayment(BuildContext context, WidgetRef ref, Repayment item) async {
  final amountCtl = TextEditingController(text: item.amountPaid.toString());
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit Repayment'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: amountCtl,
          decoration: const InputDecoration(labelText: 'Amount'),
          keyboardType: TextInputType.number,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, true);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (result == true) {
    item.amountPaid = double.parse(amountCtl.text);
    await ref.read(loanRepositoryProvider).updateRepayment(item);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repayment updated')));
    }
  }
}

Future<void> _deleteRepayment(BuildContext context, WidgetRef ref, Repayment item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Repayment?'),
      content: Text('Delete ${CurrencyFormatter.format(item.amountPaid)} repayment?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(loanRepositoryProvider).deleteRepayment(item.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repayment deleted')));
    }
  }
}

Future<void> _editMember(BuildContext context, WidgetRef ref, Member item) async {
  final nameCtl = TextEditingController(text: item.name);
  final headsCtl = TextEditingController(text: item.headsCount.toString());
  final amountCtl = TextEditingController(text: item.amountPerHead.toString());
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit Member'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const Gap(12),
            TextFormField(
              controller: headsCtl,
              decoration: const InputDecoration(labelText: 'Heads Count'),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const Gap(12),
            TextFormField(
              controller: amountCtl,
              decoration: const InputDecoration(labelText: 'Amount per Head'),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, true);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (result == true) {
    item.name = nameCtl.text;
    item.headsCount = int.parse(headsCtl.text);
    item.amountPerHead = double.parse(amountCtl.text);
    item.totalRequired = item.headsCount * item.amountPerHead;
    await ref.read(memberRepositoryProvider).updateMember(item);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member updated')));
    }
  }
}

Future<void> _deleteMember(BuildContext context, WidgetRef ref, Member item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Member?'),
      content: Text('Delete ${item.name} and all their data?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(memberRepositoryProvider).deleteMember(item.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member deleted')));
    }
  }
}

Future<void> _deletePaymentRequest(BuildContext context, WidgetRef ref, PaymentRequest item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Payment Request?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(paymentRequestRepositoryProvider).deletePaymentRequest(item.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment request deleted')));
    }
  }
}

Future<void> _deleteLoanRequest(BuildContext context, WidgetRef ref, LoanRequest item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Loan Request?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(loanRequestRepositoryProvider).deleteLoanRequest(item.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan request deleted')));
    }
  }
}
