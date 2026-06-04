import 'package:flutter/material.dart';

class LendWUsLogo extends StatelessWidget {
  final double fontSize;
  final FontWeight fontWeight;

  const LendWUsLogo({
    super.key,
    this.fontSize = 24,
    this.fontWeight = FontWeight.w800,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: -1,
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
    );
  }
}
