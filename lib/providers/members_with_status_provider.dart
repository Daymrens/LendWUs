import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/member_with_status.dart';
import 'members_provider.dart';
import 'loans_provider.dart';

final membersWithStatusProvider = FutureProvider<List<MemberWithStatus>>((ref) async {
  final members = [...?ref.watch(membersStreamProvider).asData?.value];
  final contributions = [...?ref.watch(contributionsStreamProvider).asData?.value];
  final loans = [...?ref.watch(loansStreamProvider).asData?.value];
  final now = DateTime.now();
  
  return members.map((member) {
    return MemberWithStatus.of(member, contributions, now.month, now.year, loans: loans);
  }).toList();
});
