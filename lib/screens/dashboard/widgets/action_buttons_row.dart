import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../core/theme/app_colors.dart';

class ActionButtonsRow extends StatelessWidget {
  final VoidCallback onNewContribution;
  final VoidCallback onIssueLoan;
  final VoidCallback onRecordRepayment;

  const ActionButtonsRow({
    super.key,
    required this.onNewContribution,
    required this.onIssueLoan,
    required this.onRecordRepayment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildButton('New Contribution', AppColors.primary, onNewContribution),
        const Gap(12),
        _buildButton('Issue Loan', AppColors.secondary, onIssueLoan),
        const Gap(12),
        _buildButton('Record Repayment', AppColors.warning, onRecordRepayment),
      ],
    );
  }

  Widget _buildButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
