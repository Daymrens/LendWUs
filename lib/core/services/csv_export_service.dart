import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/payment_request_repository.dart';

class CsvExportService {
  Future<void> exportContributions() async {
    final repo = ContributionRepository();
    final contributions = await repo.getAllContributions();
    final rows = [['ID', 'Member ID', 'Amount', 'Date', 'Month', 'Year']];
    for (final c in contributions) {
      rows.add([c.id ?? '', c.memberId, c.amount.toString(), c.date.toIso8601String(), c.month.toString(), c.year.toString()]);
    }
    await _shareCsv('contributions', rows);
  }

  Future<void> exportLoans() async {
    final repo = LoanRepository();
    final loans = await repo.getAllLoans();
    final rows = [['ID', 'Member ID', 'Principal', 'Interest Rate', 'Issued Date', 'Due Date', 'Fully Repaid']];
    for (final l in loans) {
      rows.add([l.id ?? '', l.memberId, l.principal.toString(), l.interestRate.toString(), l.issuedDate.toIso8601String(), l.dueDate.toIso8601String(), l.isFullyRepaid.toString()]);
    }
    await _shareCsv('loans', rows);
  }

  Future<void> exportMembers() async {
    final repo = MemberRepository();
    final members = await repo.getAllMembers();
    final rows = [['ID', 'Name', 'Heads Count', 'Amount Per Head', 'Total Required', 'Balance', 'Is Active', 'Joined At']];
    for (final m in members) {
      rows.add([m.id ?? '', m.name, m.headsCount.toString(), m.amountPerHead.toString(), m.totalRequired.toString(), m.balance.toString(), m.isActive.toString(), m.joinedAt.toIso8601String()]);
    }
    await _shareCsv('members', rows);
  }

  Future<void> exportPaymentRequests() async {
    final repo = PaymentRequestRepository();
    final requests = await repo.getAllPaymentRequests();
    final rows = [['ID', 'Member ID', 'Amount', 'Type', 'Status', 'Request Date']];
    for (final r in requests) {
      rows.add([r.id ?? '', r.memberId, r.amount.toString(), r.type.name, r.status.name, r.requestDate.toIso8601String()]);
    }
    await _shareCsv('payment_requests', rows);
  }

  Future<void> exportAll() async {
    await Future.wait([
      exportContributions(),
      exportLoans(),
      exportMembers(),
      exportPaymentRequests(),
    ]);
  }

  Future<void> _shareCsv(String name, List<List<String>> rows) async {
    final csv = rows.map((row) => row.map(_escapeCsv).join(',')).join('\n');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name.csv');
    await file.writeAsString('\uFEFF$csv');
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: '$name export'),
    );
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
