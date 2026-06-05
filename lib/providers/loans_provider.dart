import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/loan_repository.dart';
import '../data/models/loan.dart';
import '../data/models/repayment.dart';

final loanRepositoryProvider = Provider((ref) => LoanRepository());

final totalLoansProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(loanRepositoryProvider);
  return await repo.getTotalLoansIssued();
});

final totalInterestProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(loanRepositoryProvider);
  return await repo.getTotalInterestEarned();
});

// --- Stream providers (auto-refresh) ---

final loansStreamProvider = StreamProvider<List<Loan>>((ref) {
  return ref.watch(loanRepositoryProvider).watchAllLoans();
});

final activeLoansStreamProvider = StreamProvider<List<Loan>>((ref) {
  return ref.watch(loanRepositoryProvider).watchActiveLoans();
});

final repaymentsStreamProvider = StreamProvider<List<Repayment>>((ref) {
  return ref.watch(loanRepositoryProvider).watchAllRepayments();
});

final activeLoansCountProvider = Provider<int>((ref) {
  return ref.watch(activeLoansStreamProvider).asData?.value.length ?? 0;
});

final overdueLoansCountProvider = Provider<int>((ref) {
  final loans = [...?ref.watch(activeLoansStreamProvider).asData?.value];
  final now = DateTime.now();
  return loans.where((l) => !l.isFullyRepaid && l.dueDate.isBefore(now)).length;
});
