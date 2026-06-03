import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/fund_summary.dart';
import '../data/repositories/fund_repository.dart';
import '../data/repositories/loan_repository.dart';
import 'fund_provider.dart';
import 'loans_provider.dart';

final fundSummaryProvider = FutureProvider<FundSummary>((ref) async {
  final fundRepo = ref.watch(fundRepositoryProvider);
  final loanRepo = ref.watch(loanRepositoryProvider);

  final contributions = await fundRepo.getAllContributions();
  final loans = await loanRepo.getAllLoans();
  final repayments = await loanRepo.getAllRepayments();

  return FundSummary.compute(
    contributions: contributions,
    loans: loans,
    repayments: repayments,
  );
});
