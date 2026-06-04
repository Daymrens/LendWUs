import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../data/models/user.dart';
import '../../core/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) setState(() => _showContent = true);
    });
  }

  bool _showContent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.5,
            colors: [
              AppColors.surfaceAlt.withValues(alpha: 0.5),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _showContent ? 1 : 0,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DelayedWidget(delay: 0, child: _LoginHeader()),
                      SizedBox(height: 48),
                      _DelayedWidget(delay: 150, child: _LoginForm()),
                      SizedBox(height: 32),
                      _DelayedWidget(delay: 300, child: _SocialLogin()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DelayedWidget extends StatefulWidget {
  final int delay;
  final Widget child;
  const _DelayedWidget({required this.delay, required this.child});

  @override
  State<_DelayedWidget> createState() => _DelayedWidgetState();
}

class _DelayedWidgetState extends State<_DelayedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(_controller);
    Future.delayed(Duration(milliseconds: widget.delay), _controller.forward);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 64,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'LendWUs',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Financial management simplified',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      ],
    );
  }
}

class _LoginForm extends ConsumerWidget {
  const _LoginForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_loginStateProvider);
    final notifier = ref.read(_loginStateProvider.notifier);

    return Form(
      key: notifier.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: notifier.emailController,
            decoration: _getInputDecoration(
              label: 'Email Address',
              icon: Icons.alternate_email_rounded,
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter email';
              if (!value.contains('@')) return 'Please enter a valid email';
              return null;
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: notifier.passwordController,
            obscureText: state.obscurePassword,
            decoration: _getInputDecoration(
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  state.obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                onPressed: notifier.togglePasswordVisibility,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter password';
              return null;
            },
            onFieldSubmitted: (_) => notifier.login(context, ref),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: state.isLoading ? null : () => notifier.login(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: state.isLoading
                    ? const SizedBox(
                        key: ValueKey('spinner'),
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Sign In',
                        key: ValueKey('text'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialLogin extends ConsumerWidget {
  const _SocialLogin();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_loginStateProvider);
    final notifier = ref.read(_loginStateProvider.notifier);

    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.surfaceAlt)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR CONTINUE WITH',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.surfaceAlt)),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: state.isLoading ? null : () => notifier.signInWithGoogle(context, ref),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.surfaceAlt),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.login_rounded, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Sign in with Google',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _getInputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
    suffixIcon: suffixIcon,
    labelStyle: const TextStyle(color: AppColors.textMuted),
    floatingLabelStyle: const TextStyle(color: AppColors.primary),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.surfaceAlt),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
    ),
    filled: true,
    fillColor: AppColors.surfaceAlt.withValues(alpha: 0.2),
  );
}

final _loginStateProvider = StateNotifierProvider<_LoginNotifier, _LoginState>((ref) {
  return _LoginNotifier();
});

class _LoginState {
  final bool isLoading;
  final bool obscurePassword;

  _LoginState({
    this.isLoading = false,
    this.obscurePassword = true,
  });

  _LoginState copyWith({
    bool? isLoading,
    bool? obscurePassword,
  }) {
    return _LoginState(
      isLoading: isLoading ?? this.isLoading,
      obscurePassword: obscurePassword ?? this.obscurePassword,
    );
  }
}

class _LoginNotifier extends StateNotifier<_LoginState> {
  _LoginNotifier() : super(_LoginState());

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  Future<void> login(BuildContext context, WidgetRef ref) async {
    if (!formKey.currentState!.validate()) return;

    state = state.copyWith(isLoading: true);

    try {
      final success = await ref.read(currentUserProvider).login(
            emailController.text.trim(),
            passwordController.text,
          );

      if (context.mounted) {
        state = state.copyWith(isLoading: false);

        if (success) {
          final user = ref.read(currentUserProvider).state;
          if (user?.role == UserRole.admin) {
            context.go('/');
          } else {
            context.go('/member-home');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid email or password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        state = state.copyWith(isLoading: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> signInWithGoogle(BuildContext context, WidgetRef ref) async {
    state = state.copyWith(isLoading: true);
    try {
      final success = await ref.read(currentUserProvider).signInWithGoogle();
      if (context.mounted) {
        state = state.copyWith(isLoading: false);
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Sign-In failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        state = state.copyWith(isLoading: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
