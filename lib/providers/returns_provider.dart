import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/returns_info.dart';
import '../data/repositories/loan_repository.dart';
import '../core/utils/interest_calculator.dart';
import 'members_provider.dart';

final returnsInfoProvider = StreamProvider<ReturnsInfo>((ref) {
  final loanRepo = LoanRepository();
  final memberRepo = ref.watch(memberRepositoryProvider);

  final controller = StreamController<ReturnsInfo>.broadcast();

  List<dynamic> currentLoans = [];
  List<dynamic> currentRepayments = [];
  List<dynamic> currentMembers = [];

  void emit() {
    if (currentMembers.isEmpty) return;
    final totalInterest = InterestCalculator.calculateTotalInterestEarned(
      currentLoans.cast(),
      currentRepayments.cast(),
    );
    final activeMembers = currentMembers.where((m) => m.isActive).toList();
    final totalHeads = activeMembers.fold<int>(0, (sum, m) => sum + (m.headsCount as int));
    if (totalHeads == 0) {
      controller.add(ReturnsInfo(
        totalReturns: totalInterest,
        totalHeads: 0,
        perHeadShare: 0.0,
      ));
      return;
    }
    controller.add(ReturnsInfo(
      totalReturns: totalInterest,
      totalHeads: totalHeads,
      perHeadShare: InterestCalculator.calculatePerHeadShare(totalInterest, totalHeads),
    ));
  }

  final sub1 = loanRepo.watchAllLoans().listen((loans) {
    currentLoans = loans;
    emit();
  });
  final sub2 = loanRepo.watchAllRepayments().listen((repayments) {
    currentRepayments = repayments;
    emit();
  });
  final sub3 = memberRepo.watchAllMembers().listen((members) {
    currentMembers = members;
    emit();
  });

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    sub3.cancel();
    controller.close();
  });

  return controller.stream;
});
