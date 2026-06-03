import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/contribution.dart';
import 'fund_provider.dart';

final monthlyContributionsProvider = FutureProvider.family<List<Contribution>, DateTime>((ref, month) async {
  final repo = ref.watch(fundRepositoryProvider);
  return await repo.getContributionsByMonth(month);
});
