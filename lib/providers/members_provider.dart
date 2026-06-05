import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/member_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/contribution_repository.dart';
import '../data/repositories/payment_request_repository.dart';
import '../data/repositories/loan_request_repository.dart';
import '../data/repositories/head_change_request_repository.dart';
import '../data/models/member.dart';
import '../data/models/contribution.dart';
import '../data/models/payment_request.dart';
import '../data/models/loan_request.dart';
import '../data/models/head_change_request.dart';
import '../data/models/user.dart';

final memberRepositoryProvider = Provider((ref) => MemberRepository());
final userRepositoryProvider = Provider((ref) => UserRepository());
final contributionRepositoryProvider = Provider((ref) => ContributionRepository());
final paymentRequestRepositoryProvider = Provider((ref) => PaymentRequestRepository());
final loanRequestRepositoryProvider = Provider((ref) => LoanRequestRepository());
final headChangeRequestRepositoryProvider = Provider((ref) => HeadChangeRequestRepository());

final membersProvider = FutureProvider<List<Member>>((ref) async {
  final repo = ref.watch(memberRepositoryProvider);
  return await repo.getAllMembers();
});

final unlinkedUsersProvider = FutureProvider<List<User>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return await repo.getUsersWithoutMemberId();
});

// --- Stream providers (auto-refresh) ---

final membersStreamProvider = StreamProvider<List<Member>>((ref) {
  return ref.watch(memberRepositoryProvider).watchAllMembers();
});

final memberByIdProvider = StreamProvider.family<Member?, String>((ref, memberId) {
  return ref.watch(memberRepositoryProvider).watchAllMembers().map(
        (list) => list.cast<Member?>().firstWhere(
              (m) => m?.id == memberId,
              orElse: () => null,
            ),
      );
});

final contributionsStreamProvider = StreamProvider<List<Contribution>>((ref) {
  return ref.watch(contributionRepositoryProvider).watchAllContributions();
});

final paymentRequestsStreamProvider = StreamProvider<List<PaymentRequest>>((ref) {
  return ref.watch(paymentRequestRepositoryProvider).watchAllPaymentRequests();
});

final pendingPaymentRequestsStreamProvider = StreamProvider<List<PaymentRequest>>((ref) {
  return ref.watch(paymentRequestRepositoryProvider).watchPendingPaymentRequests();
});

final loanRequestsStreamProvider = StreamProvider<List<LoanRequest>>((ref) {
  return ref.watch(loanRequestRepositoryProvider).watchAllLoanRequests();
});

final pendingLoanRequestsStreamProvider = StreamProvider<List<LoanRequest>>((ref) {
  return ref.watch(loanRequestRepositoryProvider).watchPendingLoanRequests();
});

final headChangeRequestsStreamProvider = StreamProvider<List<HeadChangeRequest>>((ref) {
  return ref.watch(headChangeRequestRepositoryProvider).watchAllHeadChangeRequests();
});

final pendingHeadChangeRequestsStreamProvider = StreamProvider<List<HeadChangeRequest>>((ref) {
  return ref.watch(headChangeRequestRepositoryProvider).watchPendingHeadChangeRequests();
});

final pendingApprovalsCountProvider = Provider<int>((ref) {
  final payments = [...?ref.watch(pendingPaymentRequestsStreamProvider).asData?.value];
  final loans = [...?ref.watch(pendingLoanRequestsStreamProvider).asData?.value];
  final heads = [...?ref.watch(pendingHeadChangeRequestsStreamProvider).asData?.value];
  return payments.length + loans.length + heads.length;
});
