import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/loan_request.dart';
import '../../data/repositories/loan_request_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/currency_formatter.dart';

class MemberLoanRequestScreen extends ConsumerStatefulWidget {
  const MemberLoanRequestScreen({super.key});

  @override
  ConsumerState<MemberLoanRequestScreen> createState() => _MemberLoanRequestScreenState();
}

class _MemberLoanRequestScreenState extends ConsumerState<MemberLoanRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _interestController = TextEditingController();
  final _purposeController = TextEditingController();
  DateTime? _dueDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _interestController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select due date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentUser = ref.read(currentUserProvider).state;
    final memberRepo = MemberRepository();
    final member = await memberRepo.getMemberById(currentUser!.memberId!);
    
    final loanRequest = LoanRequest(
      memberId: currentUser.memberId!,
      memberName: member?.name ?? 'Unknown',
      amount: double.parse(_amountController.text),
      interestRate: double.parse(_interestController.text),
      notes: _purposeController.text,
      dueDate: _dueDate!,
      status: LoanRequestStatus.pending,
      requestedAt: DateTime.now(),
    );

    final repo = LoanRequestRepository();
    await repo.createLoanRequest(loanRequest);

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loan request submitted! Waiting for admin approval'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final defaultInterest = settingsAsync.valueOrNull?.loanInterestPercent ?? 10.0;

    if (_interestController.text.isEmpty && defaultInterest > 0) {
      _interestController.text = defaultInterest.toStringAsFixed(1);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Loan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Loan Amount',
                  prefixText: '${CurrencyFormatter.currencySymbol} ',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _interestController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Interest Rate',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                  helperText: 'Typical range: 5-10%',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter interest rate';
                  }
                  if (double.tryParse(value) == null || double.parse(value) < 0) {
                    return 'Please enter valid rate';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purposeController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  border: OutlineInputBorder(),
                  helperText: 'Brief description of loan purpose',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter purpose';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _selectDueDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _dueDate == null
                      ? 'Select Due Date'
                      : 'Due: ${_dueDate!.toString().split(' ')[0]}',
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withAlpha(77)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important Notes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Your request will be reviewed by admin\n'
                      '• Approval depends on fund availability\n'
                      '• You can only have one active loan at a time\n'
                      '• Interest will be added to repayment amount',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
