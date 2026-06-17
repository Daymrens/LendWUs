import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/contribution.dart';
import '../data/models/loan.dart';
import '../data/models/repayment.dart';
import '../data/models/fund_summary.dart';
import 'members_provider.dart';
import 'loans_provider.dart';

final fundSummaryProvider = FutureProvider<FundSummary>((ref) async {
  final contributionsAsync = ref.watch(contributionsStreamProvider);
  final loansAsync = ref.watch(loansStreamProvider);
  final repaymentsAsync = ref.watch(repaymentsStreamProvider);

  List<Contribution> contributions;
  List<Loan> loans;
  List<Repayment> repayments;

  if (contributionsAsync is AsyncData &&
      loansAsync is AsyncData &&
      repaymentsAsync is AsyncData) {
    contributions = contributionsAsync.value ?? [];
    loans = loansAsync.value ?? [];
    repayments = repaymentsAsync.value ?? [];
  } else {
    if (contributionsAsync is AsyncError) throw contributionsAsync.error ?? '';
    if (loansAsync is AsyncError) throw loansAsync.error ?? '';
    if (repaymentsAsync is AsyncError) throw repaymentsAsync.error ?? '';

    final results = await Future.wait([
      ref.read(contributionsStreamProvider.future),
      ref.read(loansStreamProvider.future),
      ref.read(repaymentsStreamProvider.future),
    ]);
    contributions = results[0] as List<Contribution>;
    loans = results[1] as List<Loan>;
    repayments = results[2] as List<Repayment>;
  }

  return FundSummary.compute(
    contributions: contributions,
    loans: loans,
    repayments: repayments,
  );
});
