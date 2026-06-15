import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/app_settings.dart';
import '../../providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
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
  late TextEditingController _adminEmailController;
  late TextEditingController _treasurerEmailController;
  late TextEditingController _qrNameController;
  late TextEditingController _qrNumberController;
  late TextEditingController _paymentTatController;
  String _selectedCurrencyCode = 'PHP';
  String _selectedCurrencySymbol = '\u20B1';
  List<String> _adminEmails = [];
  List<String> _treasurerEmails = [];
  bool _isMaintenanceMode = false;
  late TextEditingController _maintenanceMessageController;
  String _qrImageUrl = '';
  final _imagePicker = ImagePicker();

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
  bool _showAdvanced = false;
  bool _rolesExpanded = false;
  bool _paymentExpanded = false;

  @override
  void initState() {
    super.initState();
    _minPaymentController = TextEditingController();
    _maxPaymentController = TextEditingController();
    _loanInterestController = TextEditingController();
    _cutoffDay1Controller = TextEditingController();
    _cutoffDay2Controller = TextEditingController();
    _adminEmailController = TextEditingController();
    _treasurerEmailController = TextEditingController();
    _qrNameController = TextEditingController();
    _qrNumberController = TextEditingController();
    _paymentTatController = TextEditingController();
    _maintenanceMessageController = TextEditingController();
  }

  @override
  void dispose() {
    _minPaymentController.dispose();
    _maxPaymentController.dispose();
    _loanInterestController.dispose();
    _cutoffDay1Controller.dispose();
    _cutoffDay2Controller.dispose();
    _adminEmailController.dispose();
    _treasurerEmailController.dispose();
    _qrNameController.dispose();
    _qrNumberController.dispose();
    _paymentTatController.dispose();
    _maintenanceMessageController.dispose();
    super.dispose();
  }

  void _loadSettingsOnce(AppSettings settings) {
    if (_initialized) return;
    _minPaymentController.text = settings.minPaymentPerHead.toString();
    _maxPaymentController.text = settings.maxPaymentPerHead.toString();
    _loanInterestController.text = settings.loanInterestPercent.toString();
    _cutoffDay1Controller.text = settings.cutoffDay1.toString();
    _cutoffDay2Controller.text = settings.cutoffDay2.toString();
    _paymentTatController.text = settings.paymentTatHours.toString();
    _selectedCurrencyCode = settings.currencyCode;
    _selectedCurrencySymbol = settings.currencySymbol;
    _adminEmails = List.from(settings.adminEmails);
    _treasurerEmails = List.from(settings.treasurerEmails);
    _qrNameController.text = settings.qrAccountName;
    _qrNumberController.text = settings.qrAccountNumber;
    _qrImageUrl = settings.qrImageUrl;
    _isMaintenanceMode = settings.isMaintenanceMode;
    _maintenanceMessageController.text = settings.maintenanceMessage;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settingsAsync.when(
        data: (settings) {
          _loadSettingsOnce(settings);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFundRulesCard(),
                const Gap(16),
                _buildRolesCard(),
                const Gap(16),
                _buildPaymentInfoCard(),
                const Gap(16),
                _buildMaintenanceCard(),
                const Gap(32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
                    onTap: () => Navigator.pushNamed(context, '/data-management'),
                  ),
                ),
                const Gap(32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildFundRulesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: AppColors.primary, size: 20),
                const Gap(8),
                Text('Fund Rules',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Gap(4),
            Text('Payment limits, interest rate, cutoff dates, and turnaround time.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const Gap(20),
            _sectionLabel('Payment per Head', Icons.attach_money),
            const Gap(8),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _minPaymentController,
                  decoration: const InputDecoration(labelText: 'Minimum', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                )),
                const Gap(12),
                Expanded(child: TextFormField(
                  controller: _maxPaymentController,
                  decoration: const InputDecoration(labelText: 'Maximum', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                )),
              ],
            ),
            const Gap(20),
            _sectionLabel('Loan Interest', Icons.trending_up),
            const Gap(8),
            TextFormField(
              controller: _loanInterestController,
              decoration: const InputDecoration(
                labelText: 'Interest Rate', suffixText: '%', border: OutlineInputBorder(),
                helperText: 'Default rate for new loans',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const Gap(20),
            _sectionLabel('Currency', Icons.monetization_on),
            const Gap(8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _currencies.map((c) => DropdownMenuItem(value: c['code'], child: Text('${c['code']} (${c['symbol']})'))).toList(),
              onChanged: (value) {
                if (value != null) setState(() {
                  _selectedCurrencyCode = value;
                  _selectedCurrencySymbol = _currencies.firstWhere((c) => c['code'] == value)['symbol']!;
                });
              },
            ),
            const Gap(20),
            _sectionLabel('Cutoff Dates', Icons.calendar_today),
            const Gap(8),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _cutoffDay1Controller,
                  decoration: const InputDecoration(labelText: '1st Cutoff', border: OutlineInputBorder(), helperText: 'e.g. 13'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final d = int.tryParse(v ?? '');
                    return d == null || d < 1 || d > 31 ? '1-31' : null;
                  },
                )),
                const Gap(12),
                Expanded(child: TextFormField(
                  controller: _cutoffDay2Controller,
                  decoration: const InputDecoration(labelText: '2nd Cutoff', border: OutlineInputBorder(), helperText: 'e.g. 28'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final d = int.tryParse(v ?? '');
                    return d == null || d < 1 || d > 31 ? '1-31' : null;
                  },
                )),
              ],
            ),
            const Gap(20),
            _sectionLabel('Approval TAT', Icons.timer),
            const Gap(8),
            TextFormField(
              controller: _paymentTatController,
              decoration: const InputDecoration(
                labelText: 'Turnaround Time', suffixText: 'hours', border: OutlineInputBorder(),
                helperText: 'Estimated processing time',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final h = int.tryParse(v ?? '');
                return h == null || h < 1 ? '>= 1 hour' : null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolesCard() {
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _rolesExpanded = !_rolesExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.people, color: AppColors.secondary, size: 20),
                  const Gap(8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Roles & Access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${_adminEmails.length} admins, ${_treasurerEmails.length} treasurers',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  )),
                  Icon(_rolesExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          if (_rolesExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Admin Emails', Icons.admin_panel_settings),
                  const Gap(8),
                  Text('These users get full admin access on sign-in.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const Gap(8),
                  ..._adminEmails.asMap().entries.map((e) => ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: Text(e.value),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                      onPressed: () => setState(() => _adminEmails.removeAt(e.key)),
                    ),
                  )),
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: _adminEmailController,
                      decoration: InputDecoration(
                        labelText: _adminEmails.isEmpty ? 'Add admin email' : 'Add another',
                        border: const OutlineInputBorder(), isDense: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onFieldSubmitted: _addAdminEmail,
                    )),
                    const Gap(8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                      onPressed: () => _addAdminEmail(_adminEmailController.text),
                    ),
                  ]),
                  const Gap(24),
                  _sectionLabel('Treasurer Emails', Icons.account_balance),
                  const Gap(8),
                  Text('Treasurers can confirm bank receipts on payment requests (but not approve).',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const Gap(8),
                  ..._treasurerEmails.asMap().entries.map((e) => ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: Text(e.value),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                      onPressed: () => setState(() => _treasurerEmails.removeAt(e.key)),
                    ),
                  )),
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: _treasurerEmailController,
                      decoration: InputDecoration(
                        labelText: _treasurerEmails.isEmpty ? 'Add treasurer email' : 'Add another',
                        border: const OutlineInputBorder(), isDense: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onFieldSubmitted: _addTreasurerEmail,
                    )),
                    const Gap(8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                      onPressed: () => _addTreasurerEmail(_treasurerEmailController.text),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _paymentExpanded = !_paymentExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.qr_code, color: AppColors.warning, size: 20),
                  const Gap(8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_qrNameController.text.isEmpty ? 'No QR account set' : '${_qrNameController.text} — ${_qrNumberController.text}',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  )),
                  Icon(_paymentExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          if (_paymentExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('QR Account', Icons.account_balance_wallet),
                  const Gap(8),
                  Text('Shown to members when they make payments.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _qrNameController,
                    decoration: const InputDecoration(labelText: 'Account Name', border: OutlineInputBorder()),
                  ),
                  const Gap(12),
                  TextFormField(
                    controller: _qrNumberController,
                    decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()),
                  ),
                  const Gap(16),
                  if (_qrImageUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(base64Decode(_qrImageUrl.split(',').last), height: 150, fit: BoxFit.contain),
                        ),
                        const Gap(8),
                        TextButton.icon(
                          onPressed: () => setState(() => _qrImageUrl = ''),
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          label: const Text('Remove QR', style: TextStyle(color: AppColors.error)),
                        ),
                      ]),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _pickQrImage,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: const Text('Upload QR Image'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.construction, color: AppColors.warning, size: 20),
              const Gap(8),
              const Text('System', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Gap(4),
            Text('Maintenance mode blocks non-admin access.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const Gap(12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Maintenance Mode'),
              value: _isMaintenanceMode,
              onChanged: (val) => setState(() => _isMaintenanceMode = val),
            ),
            if (_isMaintenanceMode) ...[
              const Gap(8),
              TextFormField(
                controller: _maintenanceMessageController,
                decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 14, color: AppColors.textMuted),
      const Gap(6),
      Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
    ]);
  }

  void _addAdminEmail(String value) {
    final email = value.trim();
    if (email.isNotEmpty && email.contains('@') && !_adminEmails.contains(email)) {
      setState(() { _adminEmails.add(email); _adminEmailController.clear(); });
    }
  }

  void _addTreasurerEmail(String value) {
    final email = value.trim();
    if (email.isNotEmpty && email.contains('@') && !_treasurerEmails.contains(email)) {
      setState(() { _treasurerEmails.add(email); _treasurerEmailController.clear(); });
    }
  }

  void _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final minPay = double.parse(_minPaymentController.text);
    final maxPay = double.parse(_maxPaymentController.text);
    final interest = double.parse(_loanInterestController.text);
    final cutoff1 = int.parse(_cutoffDay1Controller.text);
    final cutoff2 = int.parse(_cutoffDay2Controller.text);
    final tatHours = int.parse(_paymentTatController.text);

    if (minPay <= 0 || maxPay <= 0) return _showError('Min and max payment must be greater than 0');
    if (minPay > maxPay) return _showError('Min payment cannot be greater than max');
    if (interest < 0 || interest > 100) return _showError('Interest rate must be between 0 and 100');
    if (cutoff1 == cutoff2) return _showError('Cutoff days must be different');

    final newSettings = AppSettings(
      minPaymentPerHead: minPay,
      maxPaymentPerHead: maxPay,
      loanInterestPercent: interest,
      currencySymbol: _selectedCurrencySymbol,
      currencyCode: _selectedCurrencyCode,
      cutoffDay1: cutoff1,
      cutoffDay2: cutoff2,
      paymentTatHours: tatHours,
      adminEmails: _adminEmails,
      treasurerEmails: _treasurerEmails,
      qrAccountName: _qrNameController.text.trim(),
      qrAccountNumber: _qrNumberController.text.trim(),
      qrImageUrl: _qrImageUrl,
      isMaintenanceMode: _isMaintenanceMode,
      maintenanceMessage: _maintenanceMessageController.text.trim(),
    );

    try {
      await ref.read(settingsRepositoryProvider).saveSettings(newSettings);
      CurrencyFormatter.updateConfiguration(_selectedCurrencySymbol, _selectedCurrencyCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      _showError('Failed to save: $e');
    }
  }

  Future<void> _pickQrImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    final b64 = base64Encode(bytes);
    setState(() => _qrImageUrl = 'data:image/png;base64,$b64');
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
    }
  }
}
