import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/fund_summary.dart';
import 'members_provider.dart';
import 'loans_provider.dart';

final fundSummaryProvider = FutureProvider<FundSummary>((ref) async {
  final contributions = [...?ref.watch(contributionsStreamProvider).asData?.value];
  final loans = [...?ref.watch(loansStreamProvider).asData?.value];
  final repayments = [...?ref.watch(repaymentsStreamProvider).asData?.value];

  return FundSummary.compute(
    contributions: contributions,
    loans: loans,
    repayments: repayments,
  );
});
