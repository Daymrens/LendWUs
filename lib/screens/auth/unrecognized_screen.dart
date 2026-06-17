import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/firebase/firebase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/user.dart';

class UnrecognizedScreen extends ConsumerStatefulWidget {
  const UnrecognizedScreen({super.key});

  @override
  ConsumerState<UnrecognizedScreen> createState() => _UnrecognizedScreenState();
}

class _UnrecognizedScreenState extends ConsumerState<UnrecognizedScreen> {
  final _nameController = TextEditingController();
  final _headsController = TextEditingController(text: '1');
  final _contactController = TextEditingController();
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _welcome = false;
  String _displayName = '';
  bool _existingUserMode = false;
  bool _showPrompt = true;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final auth = ref.read(currentUserProvider);
      final firebaseUser = FirebaseService.auth.currentUser;

      // Try to load existing member data
      String? memberId = auth.memberId;

      // If no memberId from auth, try linked email
      if (memberId == null && firebaseUser?.email != null) {
        final linked = await ref.read(memberRepositoryProvider)
            .findMemberByLinkedEmail(firebaseUser!.email!);
        if (linked != null) memberId = linked.id;
      }

      if (memberId != null) {
        final memberSnap = await FirebaseService.firestore
            .collection('members')
            .doc(memberId)
            .get();
        if (memberSnap.exists) {
          final mData = memberSnap.data() as Map<String, dynamic>;
          if (mounted) {
            _nameController.text = (mData['name'] as String?) ?? '';
            _headsController.text = ((mData['headsCount'] as int?) ?? 1).toString();
            if (mData['contactNumber'] != null) {
              _contactController.text = mData['contactNumber'] as String;
            }
            _codeController.text = 'Already joined';
            _existingUserMode = true;
            _showPrompt = false;
          }
        }
      }

      final settings = ref.read(settingsProvider);
      final defaultCode = settings.asData?.value.groupCode ?? 'LENDWUS';
      if (!_existingUserMode && mounted) {
        _codeController.text = defaultCode;
      }
    } catch (e) {
      debugPrint('UnrecognizedScreen _loadData error: $e');
    } finally {
      if (mounted) setState(() => _dataLoaded = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headsController.dispose();
    _contactController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Display name is required');
      return;
    }

    setState(() { _error = null; _submitting = true; });

    if (_existingUserMode) {
      final ok = await ref.read(currentUserProvider).completeProfile(
        name: name,
        contactNumber: _contactController.text.trim().isEmpty
            ? null : _contactController.text.trim(),
      );
      if (mounted) {
        _submitting = false;
        if (ok) {
          context.go('/member-home');
        } else {
          setState(() => _error = 'Failed to save. Please try again.');
        }
      }
      return;
    }

    // New user mode
    final heads = int.tryParse(_headsController.text.trim());
    if (heads == null || heads < 1) {
      if (mounted) setState(() { _error = 'Must have at least 1 head'; _submitting = false; });
      return;
    }
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      if (mounted) setState(() { _error = 'Group code is required'; _submitting = false; });
      return;
    }

    final result = await ref.read(currentUserProvider).joinWithGroupCode(
      code,
      displayName: name,
      headsCount: heads,
      contactNumber: _contactController.text.trim().isEmpty
          ? null : _contactController.text.trim(),
    );

    if (mounted) {
      _submitting = false;
      if (result.success) {
        setState(() { _welcome = true; _displayName = name; });
      } else {
        setState(() => _error = result.error ?? 'Invalid group code');
      }
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(currentUserProvider).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Admin escape
    if (ref.read(currentUserProvider).isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return const SizedBox.shrink();
    }

    if (!_dataLoaded) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            height: 28, width: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (_welcome) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primary],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20, offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.handshake_rounded, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to LendWUs!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hi, $_displayName!',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _step(Icons.payments_outlined, 'Pay Contribution',
                    'Start building your savings by making your first contribution payment.'),
                  const SizedBox(height: 10),
                  _step(Icons.request_page_outlined, 'Request a Loan',
                    'Apply for a loan from the fund pool once you have contributions recorded.'),
                  const SizedBox(height: 10),
                  _step(Icons.people_alt_outlined, 'Manage Your Account',
                    'Update your profile, view your contribution history, and track loan repayments.'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () => context.go('/member-home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text("Let's Get Started",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_showPrompt && !_existingUserMode) {
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(Icons.group_off_rounded, size: 44, color: AppColors.warning),
                ),
                const SizedBox(height: 24),
                Text(
                  "You're not with a group yet",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'After signing in, you need to join a savings group using a group code provided by your fund admin.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _showPrompt = false),
                    icon: const Icon(Icons.vpn_key_rounded),
                    label: const Text('I Have a Group Code',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Log Out / Exit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _existingUserMode ? Icons.edit_note_rounded : Icons.app_registration_rounded,
                size: 72,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 20),
              Text(
                _existingUserMode ? 'Complete Your Profile' : 'Complete Your Setup',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _existingUserMode
                    ? 'Please provide your display name and contact number to continue.'
                    : 'Fill in your details to join the savings fund.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              if (!_existingUserMode) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _headsController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Heads',
                    helperText: 'Each head = one share. You can change this later.',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.group_add_outlined),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              if (!_existingUserMode) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Group Code',
                    helperText: 'Ask the fund admin for the group code to join.',
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleSubmit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_existingUserMode ? 'Save' : 'Join Group'),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(IconData icon, String title, String description) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(description,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
