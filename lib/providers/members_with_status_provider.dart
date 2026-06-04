import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/member_with_status.dart';
import 'fund_provider.dart';
import 'members_provider.dart';

final membersWithStatusProvider = FutureProvider<List<MemberWithStatus>>((ref) async {
  final memberRepo = ref.watch(memberRepositoryProvider);
  final fundRepo = ref.watch(fundRepositoryProvider);

  final members = await memberRepo.getAllMembers();
  final contributions = await fundRepo.getAllContributions();
  
  final now = DateTime.now();
  
  return members.map((member) {
    return MemberWithStatus.of(member, contributions, now.month, now.year);
  }).toList();
});
