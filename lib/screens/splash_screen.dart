import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/lendwus_logo.dart';

class SplashScreen extends StatelessWidget {
  final String? statusText;

  const SplashScreen({super.key, this.statusText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LendWUsLogo(
              fontSize: 32,
              iconSize: 72,
              showIcon: true,
              showTagline: true,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.green.shade400,
              ),
            ),
            if (statusText != null) ...[
              const SizedBox(height: 16),
              Text(
                statusText!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
