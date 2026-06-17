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
  bool _showContent = false;
  String? _error;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) setState(() => _showContent = true);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit({String? prefillEmail}) async {
    final email = prefillEmail ?? _emailController.text.trim();
    if (email.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter email and password');
      return;
    }
    setState(() { _error = null; _submitting = true; });

    final result = await ref.read(currentUserProvider).login(
      email,
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _submitting = false);
      if (result.success) {
        context.go(result.role == UserRole.admin ? '/' : '/member-home');
      } else {
        setState(() => _error = result.error ?? 'Invalid email or password');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() { _error = null; _submitting = true; });

    final result = await ref.read(currentUserProvider).signInWithGoogle();

    if (mounted) {
      setState(() => _submitting = false);
      if (result.success) {
        context.go(result.role == UserRole.admin ? '/' : '/member-home');
      } else {
        setState(() => _error = result.error ?? 'Google sign-in failed');
      }
    }
  }

  Future<void> _handleSavedAccount(SavedAccount account) async {
    if (account.isGoogle) {
      setState(() { _error = null; _submitting = true; });
      final result = await ref.read(currentUserProvider).signInWithSavedAccount(account);
      if (mounted) {
        setState(() => _submitting = false);
        if (result.success) {
          context.go(result.role == UserRole.admin ? '/' : '/member-home');
        } else {
          setState(() { _showForm = true; _error = result.error; });
        }
      }
    } else {
      // Pre-fill email and show password form
      _emailController.text = account.email;
      _passwordController.clear();
      setState(() { _showForm = true; _error = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceAlt = Theme.of(context).brightness == Brightness.dark
        ? AppColors.surfaceAlt
        : AppColors.lightSurfaceAlt;
    final authNotifier = ref.watch(currentUserProvider);
    final savedAccounts = authNotifier.savedAccounts;

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _showContent ? 1 : 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary.withValues(alpha: 0.8), AppColors.primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'LendWUs',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              letterSpacing: -1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            savedAccounts.isNotEmpty && !_showForm
                                ? 'Welcome back'
                                : 'Financial management simplified',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Saved accounts picker
                      if (savedAccounts.isNotEmpty && !_showForm) ...[
                        ...savedAccounts.map((account) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AccountCard(
                            account: account,
                            onTap: _submitting ? null : () => _handleSavedAccount(account),
                            onRemove: () async {
                              await ref.read(currentUserProvider).removeSavedAccount(account.email);
                            },
                          ),
                        )),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: _submitting ? null : () => setState(() => _showForm = true),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: surfaceAlt),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                              label: Text(
                                'Sign in with another account',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Error message
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_error!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Login form
                      if (_showForm || savedAccounts.isEmpty) ...[
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                            floatingLabelStyle: const TextStyle(color: AppColors.primary),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: surfaceAlt),
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
                            fillColor: surfaceAlt.withValues(alpha: 0.2),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                            floatingLabelStyle: const TextStyle(color: AppColors.primary),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: surfaceAlt),
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
                            fillColor: surfaceAlt.withValues(alpha: 0.2),
                          ),
                          onSubmitted: (_) => _handleSubmit(),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _handleSubmit,
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
                              child: _submitting
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
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: surfaceAlt)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: surfaceAlt)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Google sign-in
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _submitting ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: surfaceAlt),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CustomPaint(painter: _GoogleIconPainter()),
                                ),
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
                        const SizedBox(height: 20),

                        // New member link
                        TextButton(
                          onPressed: () => context.go('/unrecognized'),
                          child: Text(
                            'New member? Enter group code',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],

                      // Back to account picker
                      if (savedAccounts.isNotEmpty && _showForm)
                        TextButton(
                          onPressed: () => setState(() { _showForm = false; _error = null; }),
                          child: Text(
                            'Back to saved accounts',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
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

class _AccountCard extends StatelessWidget {
  final SavedAccount account;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _AccountCard({
    required this.account,
    this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.02),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: account.photoUrl != null
                    ? NetworkImage(account.photoUrl!)
                    : null,
                child: account.photoUrl == null
                    ? Text(
                        (account.displayName.isNotEmpty
                                ? account.displayName[0]
                                : account.email[0])
                            .toUpperCase(),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                onPressed: onRemove,
                tooltip: 'Remove account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(c, r, Paint()..color = Colors.white);

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.32
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.68),
      135 * 3.14159 / 180, 270 * 3.14159 / 180, false, bluePaint,
    );

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.32
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.68),
      -45 * 3.14159 / 180, 90 * 3.14159 / 180, false, redPaint,
    );

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.32
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.68),
      45 * 3.14159 / 180, 90 * 3.14159 / 180, false, yellowPaint,
    );

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.32
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.68),
      -135 * 3.14159 / 180, 90 * 3.14159 / 180, false, greenPaint,
    );

    final barPaint = Paint()..color = const Color(0xFF4285F4);
    final barLeft = c.dx - r * 0.1;
    final barRight = c.dx + r * 0.68;
    final barTop = c.dy - r * 0.16;
    final barBottom = c.dy + r * 0.16;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(barLeft, barTop, barRight, barBottom),
        const Radius.circular(2),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
