import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/popup_message.dart';
import '../../../providers/popup_provider.dart';

class PopupOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const PopupOverlay({super.key, required this.child});

  @override
  ConsumerState<PopupOverlay> createState() => _PopupOverlayState();
}

class _PopupOverlayState extends ConsumerState<PopupOverlay> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final popup = ref.watch(randomPopupProvider);

    if (!_shown && popup != null) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeShowPopup(context, popup);
      });
    }

    return widget.child;
  }

  Future<void> _maybeShowPopup(BuildContext context, PopupMessage popup) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedDate = prefs.getString('popup_dismissed_date');
    final today = _todayString();
    if (dismissedDate == today) return;
    if (mounted) _showPopup(context, popup);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _showPopup(BuildContext context, PopupMessage popup) {
    bool _dontShowAgain = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                popup.title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                popup.message,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => setDialogState(() => _dontShowAgain = !_dontShowAgain),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _dontShowAgain
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Don't show again today",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (_dontShowAgain) {
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setString('popup_dismissed_date', _todayString());
                      });
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
