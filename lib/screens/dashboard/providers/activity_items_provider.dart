import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/members_provider.dart';
import '../../../providers/loans_provider.dart';

class ActivityItem {
  final DateTime date;
  final String type;
  final double amount;
  final String memberName;
  final String? description;

  ActivityItem({
    required this.date,
    required this.type,
    required this.amount,
    required this.memberName,
    this.description,
  });
}

final unifiedActivityProvider = Provider<List<ActivityItem>>((ref) {
  final members = [...?ref.watch(membersStreamProvider).asData?.value];
  final contributions = [...?ref.watch(contributionsStreamProvider).asData?.value];
  final loans = [...?ref.watch(loansStreamProvider).asData?.value];
  final repayments = [...?ref.watch(repaymentsStreamProvider).asData?.value];

  final memberMap = {for (var m in members) m.id: m.name};

  List<ActivityItem> items = [];

  for (var c in contributions) {
    items.add(ActivityItem(
      date: c.date,
      type: 'contribution',
      amount: c.amount,
      memberName: memberMap[c.memberId] ?? 'Unknown',
    ));
  }

  for (var l in loans) {
    items.add(ActivityItem(
      date: l.issuedDate,
      type: 'loan',
      amount: l.principal,
      memberName: memberMap[l.memberId] ?? 'Unknown',
      description: '${(l.interestRate * 100).toStringAsFixed(0)}% interest',
    ));
  }

  for (var r in repayments) {
    final loan = loans.where((l) => l.id == r.loanId).firstOrNull;
    items.add(ActivityItem(
      date: r.date,
      type: 'repayment',
      amount: r.amountPaid,
      memberName: loan != null ? (memberMap[loan.memberId] ?? 'Unknown') : 'Unknown',
      description: loan != null ? 'Loan #${loan.id}' : null,
    ));
  }

  items.sort((a, b) => b.date.compareTo(a.date));
  return items;
});
