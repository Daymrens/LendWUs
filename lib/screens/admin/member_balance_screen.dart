import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/member_repository.dart';
import '../../core/firebase/firebase_service.dart';

final memberBalanceProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final memberRepo = MemberRepository();
  final members = await memberRepo.getAllMembers();

  final results = <Map<String, dynamic>>[];
  for (final member in members) {
    final mid = member.id ?? '';
    if (mid.isEmpty) continue;

    // Only approved payment requests count toward total paid
    final paymentSnap = await FirebaseService.firestore
        .collection('payment_requests')
        .where('memberId', isEqualTo: mid)
        .where('status', isEqualTo: 'approved')
        .get();

    final totalPaidFromRequests = paymentSnap.docs.fold<double>(0.0, (sum, d) {
      final amount = (d.data()['amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });

    // Also include direct admin-recorded contributions
    final contribSnap = await FirebaseService.firestore
        .collection('contributions')
        .where('memberId', isEqualTo: mid)
        .get();

    final totalFromContributions = contribSnap.docs.fold<double>(0.0, (sum, d) {
      final amount = (d.data()['amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });

    results.add({
      'member': member,
      'totalPaid': totalPaidFromRequests + totalFromContributions,
      'balance': member.balance,
    });
  }
  results.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));
  return results;
});

class MemberBalanceScreen extends ConsumerWidget {
  const MemberBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(memberBalanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Member Balances')),
      body: balanceAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text('No members found'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = data[index];
              final member = item['member'] as dynamic;
              final balance = item['balance'] as double;
              final totalPaid = item['totalPaid'] as double;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: balance > 0
                      ? AppColors.success.withAlpha(30)
                      : AppColors.textMuted.withAlpha(30),
                  child: Text('${index + 1}',
                    style: TextStyle(
                      color: balance > 0 ? AppColors.success : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Text(member.name ?? 'Unknown'),
                subtitle: Text('Total paid: ${CurrencyFormatter.format(totalPaid)}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Credit Balance',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted.withAlpha(150)),
                    ),
                    Text(
                      CurrencyFormatter.format(balance),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: balance > 0 ? AppColors.success : AppColors.textMuted,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
