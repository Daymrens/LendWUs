import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/loan_repository.dart';

final loanRepositoryProvider = Provider((ref) => LoanRepository());

final totalLoansProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(loanRepositoryProvider);
  return await repo.getTotalLoansIssued();
});

final totalInterestProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(loanRepositoryProvider);
  return await repo.getTotalInterestEarned();
});
