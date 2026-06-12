import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/security_service.dart';
import '../../data/models/user.dart';
import '../../providers/auth_provider.dart';

class BiometricVerifyScreen extends ConsumerStatefulWidget {
  const BiometricVerifyScreen({super.key});

  @override
  ConsumerState<BiometricVerifyScreen> createState() => _BiometricVerifyScreenState();
}

class _BiometricVerifyScreenState extends ConsumerState<BiometricVerifyScreen> {
  bool _verifying = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_verify);
  }

  Future<void> _verify() async {
    if (_verifying) return;
    setState(() => _verifying = true);

    try {
      final available = await SecurityService.isBiometricAvailable();
      if (!available || !mounted) {
        setState(() {
          _verifying = false;
          _failed = true;
        });
        return;
      }

      final ok = await SecurityService.authenticateWithBiometrics();
      if (!mounted) return;

      if (ok) {
        _proceed();
      } else {
        setState(() {
          _verifying = false;
          _failed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _failed = true;
        });
      }
    }
  }

  void _proceed() {
    ref.read(currentUserProvider).clearBiometricRequirement();
    if (mounted) {
      final user = ref.read(currentUserProvider).state;
      final route = user?.role == UserRole.admin ? '/' : '/member-home';
      context.go(route);
    }
  }

  void _tryAgain() {
    setState(() => _failed = false);
    _verify();
  }

  Future<void> _usePasscode() async {
    setState(() {
      _verifying = true;
      _failed = false;
    });
    try {
      final ok = await SecurityService.authenticateWithPasscode();
      if (!mounted) return;
      if (ok) {
        _proceed();
      } else {
        setState(() {
          _verifying = false;
          _failed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).state;
    final email = user?.email ?? '';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: _failed
                        ? Icon(Icons.fingerprint, size: 44, color: AppColors.error)
                        : Icon(Icons.fingerprint, size: 44, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _failed ? 'Verification Failed' : 'Verify Your Identity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _failed
                        ? 'Could not verify your fingerprint.'
                        : 'Use your fingerprint to continue as',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                  if (!_failed) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  if (_verifying && !_failed)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  if (_failed) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _tryAgain,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TextButton(
                        onPressed: _usePasscode,
                        child: Text(
                          'Use device passcode instead',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
