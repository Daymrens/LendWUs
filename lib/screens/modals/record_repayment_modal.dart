import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/loan.dart';
import '../../data/models/repayment.dart';
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

  List<Loan> _activeLoans = const [];
  Map<String, double> _balances = const {};
  Map<String, String> _memberNames = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadLoans() async {
    final loanRepo = ref.read(loanRepositoryProvider);
    final loans = await loanRepo.getActiveLoans();
    final active = loans.where((l) => l.id != null).toList();
    final balances = <String, double>{};
    for (final loan in active) {
      balances[loan.id!] = await loanRepo.getRemainingBalance(loan.id!);
    }
    if (!mounted) return;
    setState(() {
      _activeLoans = active;
      _balances = balances;
      _loading = false;
    });
  }

  Loan? get _selectedLoan {
    return _activeLoans.cast<Loan?>().firstWhere(
      (l) => l?.id == _selectedLoanId,
      orElse: () => null,
    );
  }

  double get _selectedBalance =>
      _balances[_selectedLoanId] ?? 0.0;

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

    final balance = _selectedBalance;
    if (amount > balance) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Overpayment Warning'),
          content: Text(
            'Amount exceeds remaining balance (${CurrencyFormatter.format(balance)}). Excess will be credited to member.',
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
    ref.invalidate(totalRepaymentsProvider);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withAlpha(77),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.replay, color: AppColors.warning, size: 22),
                ),
                const Gap(14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Record Repayment',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Record a loan repayment',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const Gap(24),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withAlpha(128)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.warning, size: 20),
                    const Gap(8),
                    Expanded(
                      child: Text(_errorMessage!,
                        style: const TextStyle(color: AppColors.warning, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_activeLoans.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info, color: AppColors.textMuted, size: 32),
                    const Gap(12),
                    Text('No Active Loans',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('There are no active loans to record repayment for.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select Loan',
                  prefixIcon: const Icon(Icons.credit_card, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                ),
                items: _activeLoans.map((loan) {
                  final balance = _balances[loan.id!] ?? 0.0;
                  return DropdownMenuItem(
                    value: loan.id,
                    child: Text(
                      '${CurrencyFormatter.format(balance)} remaining',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedLoanId = value),
                validator: (value) => value == null ? 'Select a loan' : null,
              ),
            if (_selectedLoanId != null && _selectedBalance > 0) ...[
              const Gap(12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textMuted.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 18, color: AppColors.warning),
                    const Gap(10),
                    Text('Remaining Balance',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    const Spacer(),
                    Text(CurrencyFormatter.format(_selectedBalance),
                      style: const TextStyle(
                        color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
            const Gap(16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount Paid',
                prefixText: '₱ ',
                prefixIcon: const Icon(Icons.attach_money, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surfaceAlt,
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
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: const Text('Record Repayment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}
