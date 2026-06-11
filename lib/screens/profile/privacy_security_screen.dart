import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/security_service.dart';

class PrivacySecurityScreen extends ConsumerStatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  ConsumerState<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends ConsumerState<PrivacySecurityScreen> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final available = await SecurityService.isBiometricAvailable();
    final enabled = await SecurityService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      String? errorMsg;
      final ok = await SecurityService.authenticateWithBiometrics(onError: (e) => errorMsg = e);
      if (!ok) {
        if (mounted) _showBiometricStatus(errorMsg);
        return;
      }
      await SecurityService.enableBiometricAuth();
    } else {
      await SecurityService.disableBiometricAuth();
    }

    if (mounted) {
      setState(() => _biometricEnabled = value);
    }
  }

  Future<void> _showBiometricStatus([String? errorMsg]) async {
    final info = await SecurityService.isBiometricAvailable();
    final stat = await SecurityService.getBiometricStatus();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Biometric Status'),
        content: Text('Available: $info\n\nDetails: $stat\n\n${errorMsg != null ? 'Error: $errorMsg' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(currentUserProvider);
    final user = auth.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.security, size: 48, color: AppColors.primary),
                const Gap(12),
                Text('Account Security',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Gap(8),
                const Text('Manage your account data and privacy settings.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center),
              ],
            ),
          ),
          if (_biometricAvailable) ...[
            const Gap(24),
            Text('Biometric Login', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Gap(12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                    secondary: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fingerprint, size: 18, color: AppColors.primary),
                    ),
                    title: const Text('Use Fingerprint', style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                      _biometricEnabled ? 'Sign in with your fingerprint' : 'Tap to enable fingerprint sign in',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Gap(24),
          Text('Account Info', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Gap(12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined, size: 20),
                  title: const Text('Email', style: TextStyle(fontSize: 13)),
                  subtitle: Text(user?.email ?? 'N/A', style: const TextStyle(fontSize: 12)),
                ),
                if (user?.memberId != null)
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, size: 20),
                    title: const Text('Member ID', style: TextStyle(fontSize: 13)),
                    subtitle: Text(user!.memberId!, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Gap(24),
          Text('Data Management', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Gap(12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.download_outlined, size: 18, color: AppColors.primary),
                  ),
                  title: const Text('Export My Data', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Download a copy of your contribution and loan history',
                    style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data export will be available soon')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  ),
                  title: const Text('Delete Account', style: TextStyle(fontSize: 13, color: AppColors.error)),
                  subtitle: const Text('Permanently remove your account and data',
                    style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _confirmDeleteAccount(context),
                ),
              ],
            ),
          ),
          const Gap(24),
          Text('Privacy', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Gap(12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Your data is stored securely in Firebase Firestore and is only accessible '
              'to authorized group admins. We do not share your personal information with '
              'third parties. Account deletion will remove your user profile and unlink '
              'your member record.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and unlink your member record. '
          'Your contribution history will remain anonymized. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion is not yet implemented')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
