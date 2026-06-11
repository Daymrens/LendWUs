import 'dart:math';
import '../../core/firebase/firebase_service.dart';
import '../../data/repositories/notification_repository.dart';

class ReminderService {
  static Future<void> sendPaymentReminders() async {
    final firestore = FirebaseService.firestore;

    final membersSnap = await firestore
        .collection('members')
        .where('isActive', isEqualTo: true)
        .get();

    if (membersSnap.docs.isEmpty) return;

    final memberIds = membersSnap.docs.map((d) => d.id).toList();
    final nameMap = <String, String>{};
    for (final doc in membersSnap.docs) {
      nameMap[doc.id] = doc.data()['name'] ?? 'Member';
    }

    for (final chunk in _chunked(memberIds, 30)) {
      final pendingSnap = await firestore
          .collection('payment_requests')
          .where('status', isEqualTo: 'pending')
          .where('memberId', whereIn: chunk)
          .get();

      final pendingMemberIds = pendingSnap.docs
          .map((d) => d.data()['memberId'] as String)
          .toSet();

      for (final memberId in pendingMemberIds) {
        final name = nameMap[memberId] ?? memberId;
        await NotificationRepository.notifyAdmins(
          'Pending Payment Reminder',
          '$name has a pending payment request',
          type: 'reminder',
          data: {'memberId': memberId},
        );
        await NotificationRepository.notifyMember(
          memberId,
          'Payment Reminder',
          'Your payment request is still pending approval.',
          type: 'reminder',
        );
      }
    }

    for (final chunk in _chunked(memberIds, 30)) {
      final loansSnap = await firestore
          .collection('loans')
          .where('isFullyRepaid', isEqualTo: false)
          .where('memberId', whereIn: chunk)
          .get();

      if (loansSnap.docs.isEmpty) continue;

      for (final loanDoc in loansSnap.docs) {
        final memberId = loanDoc.data()['memberId'] as String;
        final name = nameMap[memberId] ?? memberId;
        final dueDate = loanDoc.data()['dueDate'];
        if (dueDate != null) {
          await NotificationRepository.notifyAdmins(
            'Loan Payment Due',
            '$name has a loan payment due',
            type: 'reminder',
            data: {'memberId': memberId, 'loanId': loanDoc.id},
          );
          await NotificationRepository.notifyMember(
            memberId,
            'Loan Payment Due',
            'Your loan payment is due. Please pay on time.',
            type: 'reminder',
          );
        }
      }
    }
  }

  static List<List<T>> _chunked<T>(List<T> items, int size) {
    final result = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      result.add(items.sublist(i, min(i + size, items.length)));
    }
    return result;
  }
}
