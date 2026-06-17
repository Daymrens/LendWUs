import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/firebase/firebase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/members_provider.dart';
import '../../providers/settings_provider.dart';

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
  bool _isLoading = false;
  String? _error;
  bool _dialogShown = false;
  bool _welcomeMode = false;
  String _displayName = '';
  bool _isExistingUser = false;
  String _defaultGroupCode = 'LENDWUS';
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeactivation();
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final auth = ref.read(currentUserProvider);
    final firebaseUser = FirebaseService.auth.currentUser;
    String? memberId = auth.memberId;

    if (memberId == null && firebaseUser?.email != null) {
      final linked = await ref.read(memberRepositoryProvider).findMemberByLinkedEmail(firebaseUser!.email!);
      if (linked != null) memberId = linked.id;
    }

    final settings = ref.read(settingsProvider);
    _defaultGroupCode = settings.asData?.value.groupCode ?? 'LENDWUS';

    if (auth.isRecognized && auth.needsSetup) {
      _isExistingUser = true;
    } else if (memberId != null) {
      _isExistingUser = true;
    }

    if (_isExistingUser && memberId != null) {
      final member = await ref.read(memberRepositoryProvider).getMemberById(memberId);
      if (member != null && mounted) {
        _nameController.text = member.name;
        _headsController.text = member.headsCount.toString();
        _codeController.text = _defaultGroupCode;
        if (member.contactNumber != null) {
          _contactController.text = member.contactNumber!;
        }
      }
    }

    if (mounted) setState(() => _dataLoaded = true);
  }

  void _checkDeactivation() {
    if (_dialogShown) return;
    final reason = ref.read(currentUserProvider).deactivationReason;
    if (reason != null) {
      _dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 28),
              SizedBox(width: 12),
              Text('Account Updated'),
            ],
          ),
          content: Text(
            reason,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                ref.read(currentUserProvider).clearDeactivationReason();
                await ref.read(currentUserProvider).logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
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

  Future<void> _submitSetup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Display name is required');
      return;
    }

    if (!_isExistingUser) {
      final heads = int.tryParse(_headsController.text.trim());
      if (heads == null || heads < 1) {
        setState(() => _error = 'Must have at least 1 head');
        return;
      }

      final code = _codeController.text.trim();
      if (code.isEmpty) {
        setState(() => _error = 'Group code is required');
        return;
      }

      setState(() { _isLoading = true; _error = null; });

      final success = await ref.read(currentUserProvider).joinWithGroupCode(
        code,
        displayName: name,
        headsCount: heads,
        contactNumber: _contactController.text.trim().isEmpty
            ? null : _contactController.text.trim(),
      );

      if (mounted) {
        if (success) {
          setState(() { _welcomeMode = true; _displayName = name; });
        } else {
          setState(() { _isLoading = false; _error = 'Invalid group code. Please try again.'; });
        }
      }
    } else {
      setState(() { _isLoading = true; _error = null; });

      final success = await ref.read(currentUserProvider).completeProfile(
        name: name,
        contactNumber: _contactController.text.trim().isEmpty
            ? null : _contactController.text.trim(),
      );

      if (mounted) {
        if (success) {
          final auth = ref.read(currentUserProvider);
          if (auth.isAdmin) {
            context.go('/');
          } else {
            context.go('/member-home');
          }
        } else {
          setState(() { _isLoading = false; _error = 'Failed to save. Please try again.'; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.read(currentUserProvider);

    // Check admin by email as backup in case _user is null (e.g. transient error)
    final firebaseUser = FirebaseService.auth.currentUser;
    final settings = ref.read(settingsProvider).asData?.value;
    final isAdminByEmail = firebaseUser?.email != null &&
        (settings?.adminEmails ?? []).contains(firebaseUser!.email);
    if (auth.isAdmin || isAdminByEmail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return const SizedBox.shrink();
    }

    if (_welcomeMode) {
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
                    width: 88,
                    height: 88,
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
                  _welcomeStep(Icons.payments_outlined, 'Pay Contribution',
                    'Start building your savings by making your first contribution payment.'),
                  const SizedBox(height: 10),
                  _welcomeStep(Icons.request_page_outlined, 'Request a Loan',
                    'Apply for a loan from the fund pool once you have contributions recorded.'),
                  const SizedBox(height: 10),
                  _welcomeStep(Icons.people_alt_outlined, 'Manage Your Account',
                    'Update your profile, view your contribution history, and track loan repayments.'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => context.go('/member-home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isExistingUser ? Icons.edit_note_rounded : Icons.app_registration_rounded,
                size: 72,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 20),
              Text(
                _isExistingUser ? 'Complete Your Profile' : 'Complete Your Setup',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isExistingUser
                    ? 'Please provide your display name and contact number to continue.'
                    : 'Fill in your details to join the savings fund.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _headsController,
                readOnly: _isExistingUser,
                decoration: InputDecoration(
                  labelText: 'Number of Heads',
                  helperText: _isExistingUser
                      ? 'To change your head count, submit a head change request.'
                      : 'Each head = one share. You can change this later.',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.group_add_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                readOnly: _isExistingUser,
                decoration: InputDecoration(
                  labelText: 'Group Code',
                  helperText: _isExistingUser
                      ? 'You are already part of the fund.'
                      : 'Ask the fund admin for the group code to join.',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: _error,
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || (_isExistingUser && !_dataLoaded) ? null : _submitSetup,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isExistingUser ? 'Save' : 'Join Group'),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(currentUserProvider).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
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

  Widget _welcomeStep(IconData icon, String title, String description) {
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
