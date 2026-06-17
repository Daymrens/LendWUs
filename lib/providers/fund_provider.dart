import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/fund_summary.dart';
import '../data/repositories/fund_repository.dart';
import 'fund_summary_provider.dart';
import 'loans_provider.dart';

final fundRepositoryProvider = Provider((ref) => FundRepository(loanRepo: ref.watch(loanRepositoryProvider)));

final totalContributionsProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(fundRepositoryProvider);
  return await repo.getTotalContributions();
});

final fundBalanceProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(fundSummaryProvider.future);
  return summary.fundBalance;
});
