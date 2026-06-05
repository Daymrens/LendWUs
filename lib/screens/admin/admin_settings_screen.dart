import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/app_settings.dart';
import '../../providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/csv_export_service.dart';

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

  final List<Map<String, String>> _currencies = [
    {'code': 'PHP', 'symbol': '\u20B1'},
    {'code': 'USD', 'symbol': '\$'},
    {'code': 'EUR', 'symbol': '€'},
    {'code': 'GBP', 'symbol': '£'},
    {'code': 'JPY', 'symbol': '¥'},
    {'code': 'KRW', 'symbol': '₩'},
    {'code': 'INR', 'symbol': '₹'},
  ];

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

  void _loadSettings(AppSettings settings) {
    if (_minPaymentController.text.isEmpty) {
      _minPaymentController.text = settings.minPaymentPerHead.toString();
    }
    if (_maxPaymentController.text.isEmpty) {
      _maxPaymentController.text = settings.maxPaymentPerHead.toString();
    }
    if (_loanInterestController.text.isEmpty) {
      _loanInterestController.text = settings.loanInterestPercent.toString();
    }
    if (_cutoffDay1Controller.text.isEmpty) {
      _cutoffDay1Controller.text = settings.cutoffDay1.toString();
    }
    if (_cutoffDay2Controller.text.isEmpty) {
      _cutoffDay2Controller.text = settings.cutoffDay2.toString();
    }
    if (_selectedCurrencyCode != settings.currencyCode && _formKey.currentState == null) {
       _selectedCurrencyCode = settings.currencyCode;
       _selectedCurrencySymbol = settings.currencySymbol;
    }
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
          _loadSettings(settings);
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
                          value: _selectedCurrencyCode,
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
    if (_formKey.currentState!.validate()) {
      final newSettings = AppSettings(
        minPaymentPerHead: double.parse(_minPaymentController.text),
        maxPaymentPerHead: double.parse(_maxPaymentController.text),
        loanInterestPercent: double.parse(_loanInterestController.text),
        currencySymbol: _selectedCurrencySymbol,
        currencyCode: _selectedCurrencyCode,
        cutoffDay1: int.parse(_cutoffDay1Controller.text),
        cutoffDay2: int.parse(_cutoffDay2Controller.text),
      );

      try {
        await ref.read(settingsRepositoryProvider).saveSettings(newSettings);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save settings: $e')),
          );
        }
      }
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

