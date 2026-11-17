import 'package:flutter/material.dart';

/// Brand palette. The four base colors are mandatory; the rest are
/// tints derived from them so screens never hardcode raw hex values.
abstract final class AppColors {
  static const wine = Color(0xFF7F1100);
  static const forest = Color(0xFF02332D);
  static const beige = Color(0xFFDACFBD);
  static const gold = Color(0xFFBF9821);

  // Derived tints
  static const background = Color(0xFFF5F0E8);
  static const surface = Color(0xFFFBF8F3);
  static const beigeSoft = Color(0xFFEDE6DA);
  static const forestSoft = Color(0xFF2E5751);
  static const textPrimary = forest;
  static const textMuted = Color(0xFF6B7A76);
  static const success = forestSoft;
  static const danger = wine;
}
