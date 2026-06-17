import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/loan_request.dart';
import '../../data/repositories/loan_request_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

class LoanRequestModal extends ConsumerStatefulWidget {
  const LoanRequestModal({super.key});

  @override
  ConsumerState<LoanRequestModal> createState() => _LoanRequestModalState();
}

class _LoanRequestModalState extends ConsumerState<LoanRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '10000');
  final _termController = TextEditingController(text: '12');
  final _purposeController = TextEditingController();
  bool _isSubmitting = false;

  double get _amount => double.tryParse(_amountController.text) ?? 0;
  int get _term => int.tryParse(_termController.text) ?? 1;

  double get _interestRate {
    final settings = ref.read(settingsProvider).asData?.value;
    return (settings?.loanInterestPercent ?? 5).toDouble();
  }

  double get _monthlyPayment {
    final rate = _interestRate / 100 / 12;
    if (rate == 0 || _term <= 0 || _amount <= 0) return _term > 0 ? _amount / _term : 0;
    final factor = _pow(1 + rate, _term);
    return (_amount * rate * factor) / (factor - 1);
  }

  double get _totalInterest => _monthlyPayment * _term - _amount;

  @override
  void dispose() {
    _amountController.dispose();
    _termController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  double _pow(double x, int n) {
    double r = 1.0;
    for (int i = 0; i < n; i++) { r *= x; }
    return r;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider).state;
    if (user?.memberId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final memberRepo = MemberRepository();
      final member = await memberRepo.getMemberById(user!.memberId!);
      final dueDate = DateTime.now().add(Duration(days: _term * 30));
      final request = LoanRequest(
        memberId: user.memberId!,
        memberName: member?.name ?? 'Unknown',
        amount: _amount,
        interestRate: _interestRate,
        dueDate: dueDate,
        status: LoanRequestStatus.pending,
        requestedAt: DateTime.now(),
        notes: _purposeController.text.isNotEmpty
            ? _purposeController.text
            : 'Loan calculator request',
      );

      final repo = LoanRequestRepository();
      await repo.createLoanRequest(request);

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle, color: AppColors.success, size: 22),
                ),
                const Gap(12),
                const Text('Loan Submitted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text('Your loan application has been submitted. Please wait for admin approval.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(fontSize: 13, color: AppColors.textMuted);
    final settings = ref.watch(settingsProvider).asData?.value;
    final interestRate = (settings?.loanInterestPercent ?? 5).toDouble();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.cardBackground, AppColors.surface],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_chart_rounded, color: AppColors.info, size: 22),
                        ),
                        const Gap(12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Apply for Loan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('Enter loan details below', style: labelStyle),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text('Loan Amount', style: labelStyle),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: '${CurrencyFormatter.currencySymbol} ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.surfaceAlt.withValues(alpha: 0.5),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter amount';
                        final a = double.tryParse(v);
                        if (a == null || a <= 0) return 'Enter valid amount';
                        if (a > 100000) return 'Max loan is ${CurrencyFormatter.format(100000)}';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [5000, 10000, 20000, 50000].map((amt) {
                        final selected = _amount == amt;
                        return GestureDetector(
                          onTap: () => setState(() => _amountController.text = amt.toString()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.info.withValues(alpha: 0.15) : AppColors.surfaceAlt.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: selected ? AppColors.info.withValues(alpha: 0.4) : Colors.transparent),
                            ),
                            child: Text(
                              CurrencyFormatter.format(amt.toDouble()),
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: selected ? AppColors.info : AppColors.textMuted,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    Text('Term (months)', style: labelStyle),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _termController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        suffixText: 'months',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.surfaceAlt.withValues(alpha: 0.5),
                      ),
                      validator: (v) {
                        final t = int.tryParse(v ?? '');
                        if (t == null || t < 1) return 'Enter valid term';
                        if (t > 36) return 'Max 36 months';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    Text('Purpose (optional)', style: labelStyle),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _purposeController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Home improvement, Business, etc.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.surfaceAlt.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_amount > 0 && _term > 0) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.info.withValues(alpha: 0.1), AppColors.info.withValues(alpha: 0.03)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          children: [
                            _summaryRow('Monthly Payment', CurrencyFormatter.format(_monthlyPayment), AppColors.info),
                            const Divider(height: 20),
                            _summaryRow('Interest Rate', '$interestRate% p.a.', AppColors.textMuted),
                            const Divider(height: 20),
                            _summaryRow('Total Interest', CurrencyFormatter.format(_totalInterest), AppColors.warning),
                            const Divider(height: 20),
                            _summaryRow('Total Payment', CurrencyFormatter.format(_monthlyPayment * _term), AppColors.success),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.info,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Apply for Loan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
