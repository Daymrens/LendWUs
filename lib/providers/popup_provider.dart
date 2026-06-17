import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase/firebase_service.dart';
import '../data/models/popup_message.dart';
import 'auth_provider.dart';
import 'loans_provider.dart';

final popupProvider = FutureProvider<List<PopupMessage>>((ref) async {
  try {
    final doc = await FirebaseService.firestore
        .collection('app_settings')
        .doc('popup_messages')
        .get();
    if (doc.exists && doc.data()?['messages'] != null) {
      final list = (doc.data()!['messages'] as List)
          .map((e) => PopupMessage.fromMap(e as Map<String, dynamic>))
          .toList();
      return [...PopupMessage.defaults, ...list];
    }
  } catch (_) {}
  return PopupMessage.defaults;
});

final randomPopupProvider = Provider<PopupMessage?>((ref) {
  final popups = ref.watch(popupProvider);
  final auth = ref.watch(currentUserProvider);
  final random = Random();

  return popups.when(
    data: (list) {
      if (list.isEmpty) return null;

      final memberId = auth.memberId;
      bool hasActiveLoan = false;
      if (memberId != null && !auth.isAdmin) {
        final loansAsync = ref.watch(activeLoansStreamProvider);
        hasActiveLoan = loansAsync.value?.any((l) => l.memberId == memberId) ?? false;
      }

      if (hasActiveLoan) {
        final loanPopups = list.where((p) => p.category == 'loan').toList();
        if (loanPopups.isNotEmpty) {
          return loanPopups[random.nextInt(loanPopups.length)];
        }
      }

      final nonLoanPopups = list.where((p) => p.category != 'loan').toList();
      if (nonLoanPopups.isEmpty) return list[random.nextInt(list.length)];
      return nonLoanPopups[random.nextInt(nonLoanPopups.length)];
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
