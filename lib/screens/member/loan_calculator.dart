import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../data/models/loan_request.dart';
import '../../data/repositories/loan_request_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../core/utils/currency_formatter.dart';

class LoanCalculatorScreen extends ConsumerStatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  ConsumerState<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends ConsumerState<LoanCalculatorScreen> {
  final _amountController = TextEditingController(text: '10000');
  final _interestRateController = TextEditingController(text: '5');
  final _termController = TextEditingController(text: '12');

  double _monthlyPayment = 0;
  double _totalInterest = 0;
  double _totalPayment = 0;
  bool _isValidLoan = false;
  String _preApprovalMessage = '';
  bool _isSubmitting = false;

  double _pow(double x, int n) {
    double result = 1.0;
    for (int i = 0; i < n; i++) {
      result *= x;
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _calculateLoan();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _interestRateController.dispose();
    _termController.dispose();
    super.dispose();
  }

  void _calculateLoan() {
    final double amount = double.tryParse(_amountController.text) ?? 0;
    final double interestRate = double.tryParse(_interestRateController.text) ?? 0;
    final int termMonths = int.tryParse(_termController.text) ?? 1;

    if (amount <= 0 || interestRate < 0 || termMonths <= 0) {
      setState(() {
        _monthlyPayment = 0;
        _totalInterest = 0;
        _totalPayment = 0;
        _isValidLoan = false;
        _preApprovalMessage = 'Please enter valid loan details.';
      });
      return;
    }

    final double monthlyRate = interestRate / 100 / 12;
    final double monthlyPayment = monthlyRate == 0
        ? amount / termMonths
        : (amount * monthlyRate * _pow(1 + monthlyRate, termMonths)) /
            (_pow(1 + monthlyRate, termMonths) - 1);

    final double totalPayment = monthlyPayment * termMonths;
    final double totalInterest = totalPayment - amount;

    setState(() {
      _monthlyPayment = monthlyPayment;
      _totalInterest = totalInterest;
      _totalPayment = totalPayment;
      _isValidLoan = _checkPreApproval(amount, monthlyPayment);
      _preApprovalMessage = _getPreApprovalMessage(amount, monthlyPayment);
    });
  }

  bool _checkPreApproval(double amount, double monthlyPayment) {
    // TODO: Query real data from Firestore (member's actual contributions, loans, history)
    // instead of using hardcoded values. This is an estimate only.
    const double totalContributions = 0;
    const double existingLoans = 0;
    const double repaymentHistory = 0;

    final bool sufficientFunds = totalContributions >= amount;
    final bool lowDebtRatio = existingLoans < totalContributions * 0.5;
    final bool goodRepaymentHistory = repaymentHistory >= 70;

    return sufficientFunds && lowDebtRatio && goodRepaymentHistory;
  }

  String _getPreApprovalMessage(double amount, double monthlyPayment) {
    if (!_isValidLoan) {
      return 'Estimated: ⚠️ Based on available data your loan may not be approved. Adjust the amount or term.';
    }
    return 'Estimated: ✅ You appear to meet the requirements for this loan.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Calculator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputSection(),
            const SizedBox(height: 16),
            _buildPreApprovalCard(),
            const SizedBox(height: 16),
            _buildResultsSection(),
            const SizedBox(height: 16),
            _buildPaymentScheduleSection(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Loan Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Loan Amount (${CurrencyFormatter.currencySymbol})',
                prefixText: '${CurrencyFormatter.currencySymbol} ',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculateLoan(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _interestRateController,
              decoration: const InputDecoration(
                labelText: 'Interest Rate (%)',
                suffixText: '% p.a.',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculateLoan(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _termController,
              decoration: const InputDecoration(
                labelText: 'Term (months)',
                suffixText: 'months',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculateLoan(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Suggested Amounts'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(title: Text('${CurrencyFormatter.currencySymbol} 5,000'), onTap: () { _amountController.text = '5000'; Navigator.pop(context); _calculateLoan(); }),
                          ListTile(title: Text('${CurrencyFormatter.currencySymbol} 10,000'), onTap: () { _amountController.text = '10000'; Navigator.pop(context); _calculateLoan(); }),
                          ListTile(title: Text('${CurrencyFormatter.currencySymbol} 20,000'), onTap: () { _amountController.text = '20000'; Navigator.pop(context); _calculateLoan(); }),
                          ListTile(title: Text('${CurrencyFormatter.currencySymbol} 50,000'), onTap: () { _amountController.text = '50000'; Navigator.pop(context); _calculateLoan(); }),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.lightbulb),
                label: const Text('Quick Select'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreApprovalCard() {
    return Card(
      elevation: 3,
      color: _isValidLoan ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _isValidLoan ? Icons.check_circle : Icons.warning,
              color: _isValidLoan ? Colors.green : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _preApprovalMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildResultRow('Monthly Payment', CurrencyFormatter.format(_monthlyPayment), Colors.blue),
            _buildResultRow('Total Interest', CurrencyFormatter.format(_totalInterest), Colors.red),
            _buildResultRow('Total Payment', CurrencyFormatter.format(_totalPayment), Colors.green),
            const SizedBox(height: 16),
            if (_totalPayment > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _totalInterest / _totalPayment,
                    backgroundColor: Colors.grey.shade200,
                    color: _isValidLoan ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Interest ratio: ${(_totalInterest / _totalPayment * 100).toStringAsFixed(1)}% of total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildPaymentScheduleSection() {
    final double amount = double.tryParse(_amountController.text) ?? 0;
    final int termMonths = int.tryParse(_termController.text) ?? 1;
    if (amount <= 0 || termMonths <= 0) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Schedule', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: termMonths.clamp(0, 24),
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final remaining = amount - (_monthlyPayment * month - _totalInterest / termMonths);
                  return ListTile(
                    dense: true,
                    title: Text('Month $month'),
                    trailing: Text(CurrencyFormatter.format(_monthlyPayment)),
                    subtitle: Text('Remaining: ${CurrencyFormatter.format(remaining)}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isValidLoan && !_isSubmitting ? () => _submitLoanRequest() : null,
              icon: const Icon(Icons.send),
              label: const Text('Apply for Loan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _resetForm,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitLoanRequest() async {
    final user = ref.read(currentUserProvider).state;
    if (user?.memberId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to apply for a loan.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Loan Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${CurrencyFormatter.format(double.tryParse(_amountController.text) ?? 0)}'),
            Text('Interest: ${_interestRateController.text}%'),
            Text('Term: ${_termController.text} months'),
            Text('Monthly: ${CurrencyFormatter.format(_monthlyPayment)}'),
            const SizedBox(height: 16),
            const Text('Are you sure you want to submit this loan application?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = LoanRequestRepository();
      final memberRepo = MemberRepository();
      final member = await memberRepo.getMemberById(user!.memberId!);

      final double amount = double.tryParse(_amountController.text) ?? 0;
      final double interestRate = double.tryParse(_interestRateController.text) ?? 0;
      final int termMonths = int.tryParse(_termController.text) ?? 1;
      final dueDate = DateTime.now().add(Duration(days: termMonths * 30));

      final request = LoanRequest(
        memberId: user.memberId!,
        memberName: member?.name ?? 'Unknown',
        amount: amount,
        interestRate: interestRate,
        dueDate: dueDate,
        status: LoanRequestStatus.pending,
        requestedAt: DateTime.now(),
        notes: 'Loan calculator request',
      );

      await repo.createLoanRequest(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting loan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      _amountController.text = '10000';
      _interestRateController.text = '5';
      _termController.text = '12';
      _calculateLoan();
    });
  }
}
