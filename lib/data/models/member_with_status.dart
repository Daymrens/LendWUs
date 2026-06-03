import 'member.dart';
import 'contribution.dart';

class MemberWithStatus {
  final Member member;
  final double requiredAmount;
  final double amountPaid;
  final double remaining;
  final double progress;
  final String paymentStatus;
  final String statusColor;

  MemberWithStatus({
    required this.member,
    required this.requiredAmount,
    required this.amountPaid,
    required this.remaining,
    required this.progress,
    required this.paymentStatus,
    required this.statusColor,
  });

  static MemberWithStatus of(
    Member member,
    List<Contribution> contributions,
    int month,
    int year,
  ) {
    final requiredAmount = member.headsCount * member.amountPerHead;

    final memberContribs = contributions.where((c) {
      return c.memberId == member.id &&
          c.date.month == month &&
          c.date.year == year;
    });

    final amountPaid = memberContribs.fold<double>(0.0, (sum, c) => sum + c.amount);
    final remaining = requiredAmount - amountPaid;
    final progress = requiredAmount > 0 ? (amountPaid / requiredAmount).clamp(0.0, 1.0) : 0.0;

    String paymentStatus;
    String statusColor;

    if (progress >= 1.0) {
      paymentStatus = 'Paid';
      statusColor = 'green';
    } else if (amountPaid == 0) {
      paymentStatus = 'Pending';
      statusColor = 'orange';
    } else {
      paymentStatus = '${(progress * 100).toStringAsFixed(0)}%';
      statusColor = 'blue';
    }

    return MemberWithStatus(
      member: member,
      requiredAmount: requiredAmount,
      amountPaid: amountPaid,
      remaining: remaining,
      progress: progress,
      paymentStatus: paymentStatus,
      statusColor: statusColor,
    );
  }
}
