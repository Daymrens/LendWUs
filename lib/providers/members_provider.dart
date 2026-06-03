import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/member_repository.dart';
import '../data/models/member.dart';

final memberRepositoryProvider = Provider((ref) => MemberRepository());

final membersProvider = FutureProvider<List<Member>>((ref) async {
  final repo = ref.watch(memberRepositoryProvider);
  return await repo.getAllMembers();
});
