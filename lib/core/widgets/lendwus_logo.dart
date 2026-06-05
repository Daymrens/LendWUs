import 'package:flutter/material.dart';

class LendWUsLogo extends StatelessWidget {
  final double fontSize;
  final double iconSize;
  final bool showIcon;
  final bool showTagline;

  const LendWUsLogo({
    super.key,
    this.fontSize = 24,
    this.iconSize = 48,
    this.showIcon = false,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          Icon(
            Icons.account_balance_wallet,
            size: iconSize,
            color: Colors.green.shade400,
          ),
          const SizedBox(height: 8),
        ],
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1,
            ),
            children: [
              const TextSpan(
                text: 'Lend',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'WUs',
                style: TextStyle(color: Colors.green.shade400),
              ),
            ],
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            'Group Sinking Fund',
            style: TextStyle(
              fontSize: fontSize * 0.4,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    );
  }
}
