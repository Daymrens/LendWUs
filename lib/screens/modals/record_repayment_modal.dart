import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/repayment.dart';
import '../../data/repositories/loan_repository.dart';
import '../../providers/loans_provider.dart';
import '../../providers/fund_summary_provider.dart';

class RecordRepaymentModal extends ConsumerStatefulWidget {
  const RecordRepaymentModal({super.key});

  @override
  ConsumerState<RecordRepaymentModal> createState() => _RecordRepaymentModalState();
}

class _RecordRepaymentModalState extends ConsumerState<RecordRepaymentModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedLoanId;
  String? _errorMessage;
  double _remainingBalance = 0.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRemainingBalance() async {
    if (_selectedLoanId != null) {
      final loanRepo = ref.read(loanRepositoryProvider);
      final balance = await loanRepo.getRemainingBalance(_selectedLoanId!);
      setState(() => _remainingBalance = balance);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedLoanId == null) {
      return;
    }

    setState(() => _errorMessage = null);

    final amount = double.parse(_amountController.text);

    if (amount <= 0) {
      setState(() => _errorMessage = 'Repayment amount must be greater than zero');
      return;
    }

    if (amount > _remainingBalance) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Overpayment Warning'),
          content: Text(
            'Amount exceeds remaining balance (${CurrencyFormatter.format(_remainingBalance)}). Excess will be credited to member.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    final repayment = Repayment(
      loanId: _selectedLoanId!,
      amountPaid: amount,
      date: DateTime.now(),
    );

    final loanRepo = ref.read(loanRepositoryProvider);
    await loanRepo.addRepayment(repayment);
    ref.invalidate(totalInterestProvider);
    ref.invalidate(fundSummaryProvider);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loanRepo = ref.read(loanRepositoryProvider);

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
              'Record Repayment',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const Gap(16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(51),
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
            FutureBuilder(
              future: loanRepo.getActiveLoans(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final activeLoans = snapshot.data!;

                if (activeLoans.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No active loans to repay'),
                  );
                }

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Select Loan'),
                  value: _selectedLoanId,
                  items: activeLoans.map((loan) {
                    return DropdownMenuItem(
                      value: loan.id,
                      child: FutureBuilder<double>(
                        future: loanRepo.getRemainingBalance(loan.id!),
                        builder: (context, balanceSnapshot) {
                          final balance = balanceSnapshot.data ?? 0.0;
                          return Text(
                            'Loan - ${CurrencyFormatter.format(balance)} remaining',
                          );
                        },
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedLoanId = value);
                    _loadRemainingBalance();
                  },
                  validator: (value) => value == null ? 'Select a loan' : null,
                );
              },
            ),
            if (_selectedLoanId != null && _remainingBalance > 0) ...[
              const Gap(8),
              Text(
                'Remaining balance: ${CurrencyFormatter.format(_remainingBalance)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
            const Gap(16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount Paid',
                prefixText: '${CurrencyFormatter.currencySymbol} ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter amount';
                if (double.tryParse(value) == null) return 'Invalid amount';
                return null;
              },
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Record Repayment',
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
