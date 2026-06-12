import 'package:flutter/material.dart';

class AppColors {
  static Brightness _brightness = Brightness.dark;

  static void init(Brightness brightness) {
    _brightness = brightness;
  }

  static Brightness get brightness => _brightness;

  static Color get surface =>
      _brightness == Brightness.dark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);

  static Color get background =>
      _brightness == Brightness.dark ? const Color(0xFF0D1117) : const Color(0xFFF3F4F6);

  static Color get surfaceAlt =>
      _brightness == Brightness.dark ? const Color(0xFF1C2333) : const Color(0xFFE5E7EB);

  static Color get cardBackground =>
      _brightness == Brightness.dark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);

  static Color get textPrimary =>
      _brightness == Brightness.dark ? const Color(0xFFF0F6FC) : const Color(0xFF111827);

  static Color get textMuted =>
      _brightness == Brightness.dark ? const Color(0xFF8B949E) : const Color(0xFF6B7280);

  static const Color primary = Color(0xFF22C55E);
  static const Color secondary = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF97316);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color success = Color(0xFF22C55E);

  static const Color lightBackground = Color(0xFFF3F4F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFE5E7EB);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextMuted = Color(0xFF6B7280);
}
