import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/firebase/firebase_service.dart';

class BulkLoanProcessingScreen extends ConsumerStatefulWidget {
  const BulkLoanProcessingScreen({super.key});

  @override
  ConsumerState<BulkLoanProcessingScreen> createState() => _BulkLoanProcessingScreenState();
}

class _BulkLoanProcessingScreenState extends ConsumerState<BulkLoanProcessingScreen> {
  final _csvController = TextEditingController();
  List<Map<String, String>> _parsed = [];
  bool _submitting = false;
  int? _successCount;
  int? _failCount;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _csvController.text.trim();
    if (text.isEmpty) return;
    final lines = text.split('\n');
    if (lines.length < 2) return;
    final headers = lines[0].split(',').map((h) => h.trim().toLowerCase()).toList();
    final memberIdIdx = headers.indexOf('memberid');
    final principalIdx = headers.indexOf('principal');
    final rateIdx = headers.indexOf('interestrate');
    final dueDateIdx = headers.indexOf('duedate');
    if (memberIdIdx < 0 || principalIdx < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV must have memberId and principal columns')),
      );
      return;
    }
    final parsed = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.length <= memberIdIdx || cols.length <= principalIdx) continue;
      parsed.add({
        'memberId': cols[memberIdIdx].trim(),
        'principal': cols[principalIdx].trim(),
        'interestRate': rateIdx >= 0 && cols.length > rateIdx ? cols[rateIdx].trim() : '5',
        'dueDate': dueDateIdx >= 0 && cols.length > dueDateIdx ? cols[dueDateIdx].trim() : '',
      });
    }
    setState(() => _parsed = parsed);
  }

  Future<void> _submit() async {
    if (_parsed.isEmpty) return;
    setState(() => _submitting = true);
    final firestore = FirebaseService.firestore;
    final batch = firestore.batch();
    int success = 0;
    int failed = 0;

    for (final entry in _parsed) {
      final principal = double.tryParse(entry['principal'] ?? '');
      final rate = double.tryParse(entry['interestRate'] ?? '5') ?? 5;
      if (principal == null || principal <= 0) { failed++; continue; }

      try {
        final existingSnap = await firestore
            .collection('loans')
            .where('memberId', isEqualTo: entry['memberId'])
            .where('isFullyRepaid', isEqualTo: false)
            .limit(1)
            .get();
        if (existingSnap.docs.isNotEmpty) { failed++; continue; }

        final dueDate = entry['dueDate']?.isNotEmpty == true
            ? DateTime.tryParse(entry['dueDate']!) ?? DateTime.now().add(const Duration(days: 180))
            : DateTime.now().add(const Duration(days: 180));

        final loanRef = firestore.collection('loans').doc();
        batch.set(loanRef, {
          'memberId': entry['memberId'],
          'principal': principal,
          'interestRate': rate / 100,
          'issuedDate': DateTime.now().toIso8601String(),
          'dueDate': dueDate.toIso8601String(),
          'isFullyRepaid': false,
        });
        success++;
      } catch (_) { failed++; }
    }

    try {
      await batch.commit();
    } catch (_) { failed = _parsed.length; success = 0; }

    setState(() {
      _submitting = false;
      _successCount = success;
      _failCount = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Loan Processing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste CSV with columns: memberId, principal, interestRate, dueDate',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const Gap(8),
            TextField(
              controller: _csvController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'memberId,principal,interestRate,dueDate\nmember1,5000,5,2026-12-31\nmember2,3000,5,',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surfaceAlt,
              ),
            ),
            const Gap(12),
            ElevatedButton(
              onPressed: _parse,
              child: const Text('Parse CSV'),
            ),
            if (_parsed.isNotEmpty) ...[
              const Gap(16),
              Text('${_parsed.length} entries parsed', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Gap(8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _parsed.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text('${_parsed[i]['memberId']} — ${CurrencyFormatter.format(double.tryParse(_parsed[i]['principal'] ?? '0') ?? 0)}'),
                    subtitle: Text('Rate: ${_parsed[i]['interestRate']}%  Due: ${_parsed[i]['dueDate'] ?? '180 days'}'),
                  ),
                ),
              ),
              const Gap(12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Create ${_parsed.length} Loans'),
                ),
              ),
            ],
            if (_successCount != null) ...[
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_failCount ?? 0) > 0 ? AppColors.error.withAlpha(30) : AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_successCount created${_failCount! > 0 ? ", $_failCount failed" : ""}',
                  style: TextStyle(
                    color: (_failCount ?? 0) > 0 ? AppColors.error : AppColors.success,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
