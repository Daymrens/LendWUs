import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/member_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/contribution_repository.dart';
import '../data/repositories/payment_request_repository.dart';
import '../data/repositories/loan_request_repository.dart';
import '../data/models/member.dart';
import '../data/models/user.dart';

final memberRepositoryProvider = Provider((ref) => MemberRepository());
final userRepositoryProvider = Provider((ref) => UserRepository());
final contributionRepositoryProvider = Provider((ref) => ContributionRepository());
final paymentRequestRepositoryProvider = Provider((ref) => PaymentRequestRepository());
final loanRequestRepositoryProvider = Provider((ref) => LoanRequestRepository());

final membersProvider = FutureProvider<List<Member>>((ref) async {
  final repo = ref.watch(memberRepositoryProvider);
  return await repo.getAllMembers();
});

final unlinkedUsersProvider = FutureProvider<List<User>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return await repo.getUsersWithoutMemberId();
});
