import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/returns_info.dart';
import '../data/repositories/returns_repository.dart';
import '../data/repositories/loan_repository.dart';
import '../data/repositories/member_repository.dart';

final returnsRepositoryProvider = Provider<ReturnsRepository>((ref) {
  return ReturnsRepository();
});

final returnsInfoProvider = StreamProvider<ReturnsInfo>((ref) {
  final repo = ref.watch(returnsRepositoryProvider);
  return repo.watchReturns();
});

final computeReturnsProvider = FutureProvider<void>((ref) async {
  final loanRepo = LoanRepository();
  final memberRepo = MemberRepository();

  final loans = await loanRepo.getAllLoans();
  final repayments = await loanRepo.getAllRepayments();
  final members = await memberRepo.getAllMembers();

  double totalInterestEarned = 0.0;
  for (var loan in loans) {
    final loanRepayments = repayments.where((r) => r.loanId == loan.id);
    final totalRepaid = loanRepayments.fold<double>(0.0, (sum, r) => sum + r.amountPaid);
    final excess = totalRepaid - loan.principal;
    if (excess > 0) totalInterestEarned += excess;
  }

  final activeMembers = members.where((m) => m.isActive).toList();
  final totalHeads = activeMembers.fold<int>(0, (sum, m) => sum + m.headsCount);

  final info = ReturnsInfo(
    totalReturns: totalInterestEarned,
    totalHeads: totalHeads,
    perHeadShare: totalHeads > 0 ? totalInterestEarned / totalHeads : 0.0,
  );

  final repo = ref.watch(returnsRepositoryProvider);
  await repo.saveReturns(info);
});
