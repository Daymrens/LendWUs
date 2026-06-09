import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member.dart';
import 'loan_repository.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/utils/member_id_generator.dart';

class MemberRepository {
  final LoanRepository _loanRepo;

  MemberRepository({LoanRepository? loanRepo}) : _loanRepo = loanRepo ?? LoanRepository();

  Future<List<Member>> getAllMembers() async {
    final snapshot = await FirebaseService.firestore.collection('members').get();
    return snapshot.docs
        .map((doc) => Member.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<Member?> getMemberById(String id) async {
    final doc = await FirebaseService.firestore.collection('members').doc(id).get();
    if (!doc.exists) return null;
    return Member.fromMap({...doc.data()!, 'id': doc.id});
  }

  Future<String> addMember(Member member, {Transaction? transaction}) async {
    final firestore = FirebaseService.firestore;
    
    Future<String> action(Transaction tx) async {
      if (member.memberId == null || member.memberId!.isEmpty) {
        member.memberId = await MemberIdGenerator.generateNextMemberId(firestore, transaction: tx);
      }
      final docRef = firestore.collection('members').doc();
      tx.set(docRef, member.toMap());
      return docRef.id;
    }

    if (transaction != null) {
      return action(transaction);
    } else {
      return firestore.runTransaction(action);
    }
  }

  Future<List<String>> addMembersSequential(List<Member> members) async {
    final firestore = FirebaseService.firestore;
    return firestore.runTransaction((tx) async {
      final ids = await MemberIdGenerator.generateNextMemberIds(firestore, members.length, transaction: tx);
      final created = <String>[];
      for (var i = 0; i < members.length; i++) {
        members[i].memberId = ids[i];
        final docRef = firestore.collection('members').doc();
        tx.set(docRef, members[i].toMap());
        created.add(docRef.id);
      }
      return created;
    });
  }

  Future<void> updateMember(Member member, {Transaction? transaction}) async {
    final firestore = FirebaseService.firestore;
    final ref = firestore.collection('members').doc(member.id!);

    Future<void> action(Transaction tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final oldMember = Member.fromMap({...snap.data()!, 'id': snap.id});
      
      // If totalRequired changed, we might need to reconcile current month balance
      if (oldMember.totalRequired != member.totalRequired) {
        final now = DateTime.now();
        final monthYear = '${now.year}-${now.month}';
        
        // Fetch all contributions for the current month to be sure
        final contribsSnap = await firestore
            .collection('contributions')
            .where('memberId', isEqualTo: member.id)
            .where('month', isEqualTo: now.month)
            .where('year', isEqualTo: now.year)
            .get();
        
        double monthTotal = contribsSnap.docs.fold<double>(
          0.0, (s, d) => s + (d.data()['amount'] as num).toDouble(),
        );

        // Adjust balance based on the new requirement
        // Current balance includes any excess from monthTotal vs oldTotalRequired
        double oldExcess = oldMember.currentMonthYear == monthYear && monthTotal > oldMember.totalRequired
            ? monthTotal - oldMember.totalRequired
            : 0.0;
        
        double newExcess = monthTotal > member.totalRequired
            ? monthTotal - member.totalRequired
            : 0.0;
        
        member.balance = (member.balance - oldExcess + newExcess).clamp(0.0, double.infinity);
        member.currentMonthTotal = monthTotal;
        member.currentMonthYear = monthYear;
      }

      tx.update(ref, member.toMap());
    }

    if (transaction != null) {
      await action(transaction);
    } else {
      await firestore.runTransaction(action);
    }
  }

  Future<void> reconcileMemberMonth(String memberId, int month, int year, {Transaction? transaction}) async {
    final firestore = FirebaseService.firestore;
    final memberRef = firestore.collection('members').doc(memberId);
    final monthYear = '$year-$month';

    Future<void> action(Transaction tx) async {
      final snap = await tx.get(memberRef);
      if (!snap.exists) return;
      final member = Member.fromMap({...snap.data()!, 'id': snap.id});

      final contribsSnap = await firestore
          .collection('contributions')
          .where('memberId', isEqualTo: memberId)
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .get();

      double monthTotal = contribsSnap.docs.fold<double>(
        0.0, (s, d) => s + (d.data()['amount'] as num).toDouble(),
      );

      double oldExcess = member.currentMonthYear == monthYear && member.currentMonthTotal > member.totalRequired
          ? member.currentMonthTotal - member.totalRequired
          : 0.0;
      
      double newExcess = monthTotal > member.totalRequired
          ? monthTotal - member.totalRequired
          : 0.0;

      tx.update(memberRef, {
        'balance': (member.balance - oldExcess + newExcess).clamp(0.0, double.infinity),
        'currentMonthTotal': monthTotal,
        'currentMonthYear': monthYear,
      });
    }

    if (transaction != null) {
      await action(transaction);
    } else {
      await firestore.runTransaction(action);
    }
  }

  Future<void> updateMemberLinkedEmail(String memberId, String? email) async {
    await FirebaseService.firestore
        .collection('members')
        .doc(memberId)
        .update({'linkedEmail': email});
  }

  Future<void> deleteMember(String id) async {
    if (await _loanRepo.hasActiveLoan(id)) {
      throw Exception('Cannot remove member with outstanding loan');
    }

    final firestore = FirebaseService.firestore;

    final pendingPayments = await firestore
        .collection('payment_requests')
        .where('memberId', isEqualTo: id)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (pendingPayments.docs.isNotEmpty) {
      throw Exception('Cannot remove member with pending payment requests');
    }

    final pendingLoans = await firestore
        .collection('loan_requests')
        .where('memberId', isEqualTo: id)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (pendingLoans.docs.isNotEmpty) {
      throw Exception('Cannot remove member with pending loan requests');
    }

    await firestore.collection('members').doc(id).delete();
  }

  Stream<List<Member>> watchAllMembers() {
    return FirebaseService.firestore.collection('members').snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => Member.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<Member?> findMemberByLinkedEmail(String email) async {
    final snapshot = await FirebaseService.firestore
        .collection('members')
        .where('linkedEmail', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Member.fromMap({...snapshot.docs.first.data(), 'id': snapshot.docs.first.id});
  }
}
