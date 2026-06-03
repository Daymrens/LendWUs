import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/fund_repository.dart';

final fundRepositoryProvider = Provider((ref) => FundRepository());

final totalFundProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(fundRepositoryProvider);
  return await repo.getTotalFund();
});
