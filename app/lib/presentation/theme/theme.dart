import 'dart:io';

import 'package:flutter/material.dart';

/// Colours beyond what ColorScheme covers, kept together so light and dark
/// stay in step.
@immutable
class TetherColors extends ThemeExtension<TetherColors> {
  const TetherColors({
    required this.canvas,
    required this.sidebar,
    required this.surface,
    required this.raised,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.codeBg,
    required this.userBubble,
    required this.diffAdd,
    required this.diffRemove,
  });

  final Color canvas, sidebar, surface, raised, border, text, muted, faint;
  final Color accent, success, warning, danger, info;
  final Color codeBg, userBubble, diffAdd, diffRemove;

  static const light = TetherColors(
    canvas: Color(0xFFFAF9F5),
    sidebar: Color(0xFFF3F1EA),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEFEDE6),
    border: Color(0xFFE3E0D6),
    text: Color(0xFF1F1E1B),
    muted: Color(0xFF6B675E),
    faint: Color(0xFF9C978C),
    accent: Color(0xFFC2603E),
    success: Color(0xFF3E7D52),
    warning: Color(0xFFB07A12),
    danger: Color(0xFFB4443A),
    info: Color(0xFF3F6CA8),
    codeBg: Color(0xFFF2F0E9),
    userBubble: Color(0xFFEFECE3),
    diffAdd: Color(0x2E3E7D52),
    diffRemove: Color(0x2EB4443A),
  );

  static const dark = TetherColors(
    canvas: Color(0xFF262624),
    sidebar: Color(0xFF1F1E1D),
    surface: Color(0xFF30302E),
    raised: Color(0xFF383835),
    border: Color(0xFF3E3D39),
    text: Color(0xFFECEAE3),
    muted: Color(0xFFA6A297),
    faint: Color(0xFF79756C),
    accent: Color(0xFFD97757),
    success: Color(0xFF6DB384),
    warning: Color(0xFFD9A441),
    danger: Color(0xFFE07A6E),
    info: Color(0xFF7FA6DB),
    codeBg: Color(0xFF1E1E1C),
    userBubble: Color(0xFF3A3936),
    diffAdd: Color(0x336DB384),
    diffRemove: Color(0x33E07A6E),
  );

  @override
  TetherColors copyWith() => this;

  @override
  TetherColors lerp(TetherColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension TetherTheme on BuildContext {
  TetherColors get colors => Theme.of(this).extension<TetherColors>()!;
}

final String monoFont = Platform.isWindows ? 'Cascadia Mono' : 'monospace';
const List<String> monoFallback = ['Consolas', 'Menlo', 'monospace'];

TextStyle monoStyle(BuildContext context, {double size = 13, Color? color}) => TextStyle(
      fontFamily: monoFont,
      fontFamilyFallback: monoFallback,
      fontSize: size,
      height: 1.45,
      color: color ?? context.colors.text,
    );

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? TetherColors.light : TetherColors.dark;
  final scheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness).copyWith(
    primary: c.accent,
    onPrimary: Colors.white,
    surface: c.canvas,
    onSurface: c.text,
    outline: c.border,
    outlineVariant: c.border,
    error: c.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.canvas,
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
  );
  final text = base.textTheme.apply(bodyColor: c.text, displayColor: c.text);
  return base.copyWith(
    textTheme: text.copyWith(
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14.5, height: 1.5),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15.5, height: 1.6),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.canvas,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.accent)),
      hintStyle: TextStyle(color: c.faint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.canvas,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.canvas,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: c.border)),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: c.text),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(6)),
      textStyle: TextStyle(color: c.canvas, fontSize: 12),
    ),
  );
}
