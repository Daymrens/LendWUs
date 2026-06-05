import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/app_settings.dart';
import '../../providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/csv_export_service.dart';
import '../../core/utils/currency_formatter.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _minPaymentController;
  late TextEditingController _maxPaymentController;
  late TextEditingController _loanInterestController;
  late TextEditingController _cutoffDay1Controller;
  late TextEditingController _cutoffDay2Controller;
  String _selectedCurrencyCode = 'PHP';
  String _selectedCurrencySymbol = '\u20B1';

  final List<Map<String, String>> _currencies = const [
    {'code': 'PHP', 'symbol': '\u20B1'},
    {'code': 'USD', 'symbol': '\$'},
    {'code': 'EUR', 'symbol': '€'},
    {'code': 'GBP', 'symbol': '£'},
    {'code': 'JPY', 'symbol': '¥'},
    {'code': 'KRW', 'symbol': '₩'},
    {'code': 'INR', 'symbol': '₹'},
  ];

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _minPaymentController = TextEditingController();
    _maxPaymentController = TextEditingController();
    _loanInterestController = TextEditingController();
    _cutoffDay1Controller = TextEditingController();
    _cutoffDay2Controller = TextEditingController();
  }

  @override
  void dispose() {
    _minPaymentController.dispose();
    _maxPaymentController.dispose();
    _loanInterestController.dispose();
    _cutoffDay1Controller.dispose();
    _cutoffDay2Controller.dispose();
    super.dispose();
  }

  void _loadSettingsOnce(AppSettings settings) {
    if (_initialized) return;
    _minPaymentController.text = settings.minPaymentPerHead.toString();
    _maxPaymentController.text = settings.maxPaymentPerHead.toString();
    _loanInterestController.text = settings.loanInterestPercent.toString();
    _cutoffDay1Controller.text = settings.cutoffDay1.toString();
    _cutoffDay2Controller.text = settings.cutoffDay2.toString();
    _selectedCurrencyCode = settings.currencyCode;
    _selectedCurrencySymbol = settings.currencySymbol;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
      ),
      body: settingsAsync.when(
        data: (settings) {
          _loadSettingsOnce(settings);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Fund Configuration',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const Gap(24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment per Head Limits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Gap(16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _minPaymentController,
                                decoration: InputDecoration(
                                  labelText: 'Minimum',
                                  prefixText: '$_selectedCurrencySymbol ',
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  if (double.tryParse(value) == null) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            const Gap(16),
                            Expanded(
                              child: TextFormField(
                                controller: _maxPaymentController,
                                decoration: InputDecoration(
                                  labelText: 'Maximum',
                                  prefixText: '$_selectedCurrencySymbol ',
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  if (double.tryParse(value) == null) return 'Invalid';
                                  final min = double.tryParse(_minPaymentController.text) ?? 0;
                                  if (double.parse(value) < min) return 'Must be >= Min';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Currency Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Gap(16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCurrencyCode,
                          decoration: const InputDecoration(
                            labelText: 'Select Currency',
                            border: OutlineInputBorder(),
                          ),
                          items: _currencies.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['code'],
                              child: Text('${c['code']} (${c['symbol']})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCurrencyCode = value;
                                _selectedCurrencySymbol = _currencies.firstWhere((c) => c['code'] == value)['symbol']!;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                ),
              ),
                const Gap(24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Loan Interest',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Gap(16),
                        TextFormField(
                          controller: _loanInterestController,
                          decoration: const InputDecoration(
                            labelText: 'Interest Rate',
                            suffixText: '%',
                            border: OutlineInputBorder(),
                            helperText: 'Default interest rate for new loans',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (double.tryParse(value) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Cutoff Dates',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Gap(8),
                        const Text('Payments are due on these days each month. Members can pay early or on time.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        const Gap(16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cutoffDay1Controller,
                                decoration: const InputDecoration(
                                  labelText: '1st Cutoff Day',
                                  border: OutlineInputBorder(),
                                  helperText: 'e.g. 13',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  final day = int.tryParse(value);
                                  if (day == null || day < 1 || day > 31) return '1-31';
                                  return null;
                                },
                              ),
                            ),
                            const Gap(16),
                            Expanded(
                              child: TextFormField(
                                controller: _cutoffDay2Controller,
                                decoration: const InputDecoration(
                                  labelText: '2nd Cutoff Day',
                                  border: OutlineInputBorder(),
                                  helperText: 'e.g. 28',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  final day = int.tryParse(value);
                                  if (day == null || day < 1 || day > 31) return '1-31';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save Settings'),
                  ),
                ),
                const Gap(24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storage, color: AppColors.warning),
                    title: const Text('Data Management'),
                    subtitle: const Text('Edit, add, delete transactions and clear all data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/data-management'),
                  ),
                ),
                const Gap(16),
                Text('Export Data', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Gap(8),
                Row(
                  children: [
                    Expanded(child: _exportButton('Contributions', Icons.attach_money, () => CsvExportService().exportContributions())),
                    const Gap(8),
                    Expanded(child: _exportButton('Loans', Icons.account_balance, () => CsvExportService().exportLoans())),
                  ],
                ),
                const Gap(8),
                Row(
                  children: [
                    Expanded(child: _exportButton('Members', Icons.people, () => CsvExportService().exportMembers())),
                    const Gap(8),
                    Expanded(child: _exportButton('Payments', Icons.receipt, () => CsvExportService().exportPaymentRequests())),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final minPay = double.parse(_minPaymentController.text);
    final maxPay = double.parse(_maxPaymentController.text);
    final interest = double.parse(_loanInterestController.text);
    final cutoff1 = int.parse(_cutoffDay1Controller.text);
    final cutoff2 = int.parse(_cutoffDay2Controller.text);

    if (minPay <= 0 || maxPay <= 0) {
      _showError('Min and max payment must be greater than 0');
      return;
    }
    if (minPay > maxPay) {
      _showError('Min payment cannot be greater than max');
      return;
    }
    if (interest < 0 || interest > 100) {
      _showError('Interest rate must be between 0 and 100');
      return;
    }
    if (cutoff1 == cutoff2) {
      _showError('Cutoff days must be different');
      return;
    }

    final newSettings = AppSettings(
      minPaymentPerHead: minPay,
      maxPaymentPerHead: maxPay,
      loanInterestPercent: interest,
      currencySymbol: _selectedCurrencySymbol,
      currencyCode: _selectedCurrencyCode,
      cutoffDay1: cutoff1,
      cutoffDay2: cutoff2,
    );

    try {
      await ref.read(settingsRepositoryProvider).saveSettings(newSettings);
      CurrencyFormatter.updateConfiguration(_selectedCurrencySymbol, _selectedCurrencyCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      _showError('Failed to save settings: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _exportButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

