import 'package:flutter/material.dart';

/// Brand palette plus the semantic roles screens should use.
///
/// Screens use the *roles* (background, surface, accent, …), never raw hex
/// values, so the look changes in one place. Roles resolve against the active
/// [Brightness], set by the app with [use] before building the widget tree
/// (the tree is rebuilt whenever the theme changes).
///
/// Dark: black background, forest-tinted cards, gold as the single accent,
/// wine for hearts/alerts, leaf for success.
/// Light: cream background, white cards, night text, wine as the accent.
abstract final class AppColors {
  // --- Base colors (mandatory) ---
  static const wine = Color(0xFF7F1100);
  static const forest = Color(0xFF02332D);
  static const beige = Color(0xFFDACFBD);
  static const gold = Color(0xFFBF9821);
  static const night = Color(0xFF031C04); // near-black green
  static const sage = Color(0xFF6B8383); // grey-green
  static const leaf = Color(0xFF195609); // deep leaf green

  static Brightness _brightness = Brightness.dark;

  /// Selects which palette the roles below return.
  static void use(Brightness brightness) => _brightness = brightness;
  static bool get isDark => _brightness == Brightness.dark;

  static _Roles get _r => isDark ? _dark : _light;

  // --- Roles ---

  /// App background.
  static Color get background => _r.background;

  /// Cards, rows, sheets.
  static Color get surface => _r.surface;

  /// Raised elements on a surface: chips, inputs, icon tiles, progress tracks.
  static Color get surfaceHigh => _r.surfaceHigh;

  /// Hairline separators and the rare border.
  static Color get line => _r.line;

  /// Main text.
  static Color get textPrimary => _r.textPrimary;

  /// Secondary text and inactive icons.
  static Color get textMuted => _r.textMuted;

  /// The single accent: buttons, selection, links.
  static Color get accent => _r.accent;

  /// Text and icons placed on [accent].
  static Color get onAccent => _r.onAccent;

  /// Hearts, alerts, destructive actions and removed items.
  static Color get danger => _r.danger;

  /// Added items, confirmations.
  static Color get success => _r.success;

  static const _dark = _Roles(
    background: Color(0xFF000000), // black
    surface: Color(0xFF07291D), // night mixed with forest
    surfaceHigh: Color(0xFF0D3A30), // forest lifted
    line: Color(0x336B8383), // sage, faint
    textPrimary: Color(0xFFF1ECE3), // beige lightened
    textMuted: Color(0xFF9DB0AE), // sage lightened
    accent: gold,
    onAccent: night,
    danger: Color(0xFFD0533B), // wine lifted for dark backgrounds
    success: Color(0xFF6BB04F), // leaf lifted for dark backgrounds
  );

  static const _light = _Roles(
    background: Color(0xFFF5F0E8), // cream (beige tint)
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEDE6DA), // beige soft
    line: Color(0x66DACFBD), // beige, faint
    textPrimary: night,
    textMuted: Color(0xFF52696A), // sage darkened for contrast on cream
    accent: wine, // gold is too light on cream; wine reads well
    onAccent: Color(0xFFFFFFFF),
    danger: wine,
    success: leaf,
  );
}

class _Roles {
  const _Roles({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color line;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color success;
}
