import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/notification_repository.dart';
import '../../core/firebase/firebase_service.dart';

class AllPaidWatcher {
  StreamSubscription<QuerySnapshot>? _contributionsSub;
  StreamSubscription<QuerySnapshot>? _membersSub;
  int _lastNotifiedMonth = -1;
  int _lastNotifiedYear = -1;
  bool _disposed = false;

  void start() {
    _lastNotifiedMonth = -1;
    _lastNotifiedYear = -1;
    _disposed = false;

    // Listen to members and contributions changes
    _membersSub = FirebaseService.firestore
        .collection('members')
        .snapshots()
        .listen((_) => _checkAllPaid(), onError: (e) => debugPrint('AllPaidWatcher members error: $e'));

    _contributionsSub = FirebaseService.firestore
        .collection('contributions')
        .snapshots()
        .listen((_) => _checkAllPaid(), onError: (e) => debugPrint('AllPaidWatcher contributions error: $e'));
  }

  Future<void> _checkAllPaid() async {
    if (_disposed) return;

    final now = DateTime.now();
    final thisMonth = now.month;
    final thisYear = now.year;

    // Don't notify if we already sent one this month
    if (_lastNotifiedMonth == thisMonth && _lastNotifiedYear == thisYear) return;

    try {
      final membersSnapshot = await FirebaseService.firestore
          .collection('members')
          .where('isActive', isEqualTo: true)
          .get();

      if (membersSnapshot.docs.isEmpty) return;

      final contributionsSnapshot = await FirebaseService.firestore
          .collection('contributions')
          .get();

      var allPaid = true;
      var totalMembers = 0;
      var paidCount = 0;

      for (final memberDoc in membersSnapshot.docs) {
        final memberData = memberDoc.data();
        final memberId = memberDoc.id;
        final headsCount = (memberData['headsCount'] as num?)?.toInt() ?? 1;
        final amountPerHead = (memberData['amountPerHead'] as num?)?.toDouble() ?? 0.0;
        final totalRequired = (memberData['totalRequired'] as num?)?.toDouble() ?? (headsCount * amountPerHead);

        if (totalRequired <= 0) continue;

        totalMembers++;

        final monthContribs = contributionsSnapshot.docs
            .where((doc) {
              final data = doc.data();
              final d = _parseDate(data['date']);
              return data['memberId'] == memberId
                  && d != null
                  && d.month == thisMonth
                  && d.year == thisYear;
            })
            .fold<double>(0.0, (total, doc) {
              final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
              return total + amount;
            });

        if (monthContribs >= totalRequired) {
          paidCount++;
        } else {
          allPaid = false;
        }
      }

      if (allPaid && totalMembers > 0) {
        _lastNotifiedMonth = thisMonth;
        _lastNotifiedYear = thisYear;

        final monthNames = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December',
        ];

        await NotificationRepository.notifyAll(
          'All Members Paid! 🎉',
          'All $totalMembers active members have completed their ${monthNames[thisMonth - 1]} contributions. Great work!',
          type: 'all_paid',
          data: {
            'month': thisMonth,
            'year': thisYear,
            'totalMembers': totalMembers,
            'paidCount': paidCount,
          },
        );

        debugPrint('AllPaidWatcher: All $totalMembers members paid for ${monthNames[thisMonth - 1]}. Notification sent.');
      }
    } catch (e) {
      debugPrint('AllPaidWatcher error: $e');
    }
  }

  DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is String) return DateTime.tryParse(date);
    return null;
  }

  void dispose() {
    _disposed = true;
    _contributionsSub?.cancel();
    _membersSub?.cancel();
    _contributionsSub = null;
    _membersSub = null;
  }
}
