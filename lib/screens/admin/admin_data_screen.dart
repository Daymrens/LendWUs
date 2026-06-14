import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/contribution.dart';
import '../../data/models/loan.dart';
import '../../data/models/repayment.dart';
import '../../data/models/member.dart';
import '../../data/models/payment_request.dart';
import '../../data/models/loan_request.dart';
import '../../providers/loans_provider.dart';
import '../../providers/members_provider.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/utils/member_id_generator.dart';

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

  Future<void> _backfillMemberIds() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backfill Member IDs?'),
        content: const Text(
          'This will generate formatted IDs (LWS000000) for all members missing them, '
          'ordered by their join date.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Backfill Now'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final count = await MemberIdGenerator.backfillMissingMemberIds(FirebaseService.firestore);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backfilled $count members successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error backfilling: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Backfill Member IDs',
            onPressed: _backfillMemberIds,
          ),
        ],
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

final _contributionsListProvider = FutureProvider<List<Contribution>>((ref) {
  return ref.watch(contributionRepositoryProvider).getAllContributions();
});

class _ContributionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributionsAsync = ref.watch(_contributionsListProvider);
    final membersAsync = ref.watch(_membersListProvider);
    return contributionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading contributions')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No contributions'));
        }
        final memberNames = switch (membersAsync) {
          AsyncData(:final value) => {for (final m in value) m.id: m.name},
          _ => <String?, String>{},
        };
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final memberName = memberNames[item.memberId] ?? item.memberId ?? 'Unknown';
            return _DataTile(
              title: CurrencyFormatter.format(item.amount),
              subtitle: '${item.date.day}/${item.date.month}/${item.date.year}',
              trailing: memberName,
              onEdit: () => _editContribution(context, ref, item),
              onDelete: () => _deleteContribution(context, ref, item),
            );
          },
        );
      },
    );
  }
}

final _loansListProvider = FutureProvider<List<Loan>>((ref) {
  return ref.watch(loanRepositoryProvider).getAllLoans();
});

class _LoansTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(_loansListProvider);
    final membersAsync = ref.watch(_membersListProvider);
    return loansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading loans')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No loans'));
        }
        final memberNames = switch (membersAsync) {
          AsyncData(:final value) => {for (final m in value) m.id: m.name},
          _ => <String?, String>{},
        };
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final status = item.isFullyRepaid ? 'Paid' : 'Active';
            final memberName = memberNames[item.memberId] ?? item.memberId ?? 'Unknown';
            return _DataTile(
              title: '${CurrencyFormatter.format(item.principal)} ($status)',
              subtitle: 'Issued: ${item.issuedDate.day}/${item.issuedDate.month}/${item.issuedDate.year}',
              trailing: memberName,
              onEdit: () => _editLoan(context, ref, item),
              onDelete: () => _deleteLoan(context, ref, item),
            );
          },
        );
      },
    );
  }
}

final _repaymentsListProvider = FutureProvider<List<Repayment>>((ref) {
  return ref.watch(loanRepositoryProvider).getAllRepayments();
});

class _RepaymentsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repaymentsAsync = ref.watch(_repaymentsListProvider);
    return repaymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading repayments')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No repayments'));
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
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

final _membersListProvider = FutureProvider<List<Member>>((ref) {
  return ref.watch(memberRepositoryProvider).getAllMembers();
});

class _MembersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(_membersListProvider);
    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading members')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No members'));
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
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

final _paymentRequestsListProvider = FutureProvider<List<PaymentRequest>>((ref) {
  return ref.watch(paymentRequestRepositoryProvider).getAllPaymentRequests();
});

class _PaymentRequestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_paymentRequestsListProvider);
    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading payment requests')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No payment requests'));
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _DataTile(
              title: '${CurrencyFormatter.format(item.amount)} • ${item.type.name}',
              subtitle: '${item.memberId}  •  ${item.status.name}',
              trailing: item.requestDate.day.toString(),
              onEdit: null,
              onDelete: () => _deletePaymentRequest(context, ref, item),
            );
          },
        );
      },
    );
  }
}

final _loanRequestsListProvider = FutureProvider<List<LoanRequest>>((ref) {
  return ref.watch(loanRequestRepositoryProvider).getAllLoanRequests();
});

class _LoanRequestsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_loanRequestsListProvider);
    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading loan requests')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No loan requests'));
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
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
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
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
    ref.invalidate(_contributionsListProvider);
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
    ref.invalidate(_contributionsListProvider);
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
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const Gap(12),
            TextFormField(
              controller: interestCtl,
              decoration: const InputDecoration(labelText: 'Interest Rate %'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid rate';
                return null;
              },
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
    ref.invalidate(_loansListProvider);
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
    ref.invalidate(_loansListProvider);
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
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            final n = double.tryParse(v);
            if (n == null || n <= 0) return 'Enter a valid amount';
            return null;
          },
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
    ref.invalidate(_repaymentsListProvider);
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
    ref.invalidate(_repaymentsListProvider);
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
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = int.tryParse(v);
                if (n == null || n < 1) return 'Must be at least 1';
                return null;
              },
            ),
            const Gap(12),
            TextFormField(
              controller: amountCtl,
              decoration: const InputDecoration(labelText: 'Amount per Head'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
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
    ref.invalidate(_membersListProvider);
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
    ref.invalidate(_membersListProvider);
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
    ref.invalidate(_paymentRequestsListProvider);
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
    ref.invalidate(_loanRequestsListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan request deleted')));
    }
  }
}
