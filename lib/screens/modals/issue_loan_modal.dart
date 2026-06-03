import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/loan.dart';
import '../../providers/loans_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/fund_summary_provider.dart';
import '../../data/repositories/loan_repository.dart';

class IssueLoanModal extends ConsumerStatefulWidget {
  const IssueLoanModal({super.key});

  @override
  ConsumerState<IssueLoanModal> createState() => _IssueLoanModalState();
}

class _IssueLoanModalState extends ConsumerState<IssueLoanModal> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController(text: '5');
  String? _selectedMemberId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String? _errorMessage;

  @override
  void dispose() {
    _principalController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedMemberId == null) {
      return;
    }

    setState(() => _errorMessage = null);

    final principal = double.parse(_principalController.text);
    final interestRate = double.parse(_interestController.text) / 100;

    final fundSummary = await ref.read(fundSummaryProvider.future);
    final loanRepo = ref.read(loanRepositoryProvider);

    if (principal <= 0) {
      setState(() => _errorMessage = 'Loan amount must be greater than zero');
      return;
    }

    if (principal > fundSummary.availableToLoan) {
      setState(() => _errorMessage = 'Insufficient fund balance. Available: ${fundSummary.availableToLoan.toStringAsFixed(2)}');
      return;
    }

    final hasActive = await loanRepo.hasActiveLoan(_selectedMemberId!);
    if (hasActive) {
      setState(() => _errorMessage = 'Member already has an unpaid loan');
      return;
    }

    if (_dueDate.isBefore(DateTime.now())) {
      setState(() => _errorMessage = 'Due date must be in the future');
      return;
    }

    final loan = Loan(
      memberId: _selectedMemberId!,
      principal: principal,
      interestRate: interestRate,
      issuedDate: DateTime.now(),
      dueDate: _dueDate,
    );

    await loanRepo.addLoan(loan);
    ref.invalidate(totalLoansProvider);
    ref.invalidate(fundSummaryProvider);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider);
    final fundSummary = ref.watch(fundSummaryProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issue Loan',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const Gap(8),
            fundSummary.when(
              data: (summary) => Text(
                'Available to loan: ${summary.availableToLoan.toStringAsFixed(2)}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const Gap(16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.warning, size: 20),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            members.when(
              data: (list) => DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Member'),
                value: _selectedMemberId,
                items: list.map((member) {
                  return DropdownMenuItem(
                    value: member.id,
                    child: Text(member.name),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedMemberId = value),
                validator: (value) => value == null ? 'Select a member' : null,
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading members'),
            ),
            const Gap(16),
            TextFormField(
              controller: _principalController,
              decoration: const InputDecoration(
                labelText: 'Principal Amount',
                prefixText: '₱ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter amount';
                if (double.tryParse(value) == null) return 'Invalid amount';
                return null;
              },
            ),
            const Gap(16),
            TextFormField(
              controller: _interestController,
              decoration: const InputDecoration(
                labelText: 'Interest Rate',
                suffixText: '%',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter rate';
                if (double.tryParse(value) == null) return 'Invalid rate';
                return null;
              },
            ),
            const Gap(16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due Date'),
              subtitle: Text('${_dueDate.day}/${_dueDate.month}/${_dueDate.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _dueDate = date);
                }
              },
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Issue Loan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}
