import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Spacing steps: every gap in the app is one of these.
abstract final class Gap {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24;

  /// The margin at the edge of a page.
  static double page(BuildContext context) => MediaQuery.sizeOf(context).width < 600 ? md : xl;
}

/// Text styles that aren't Inter's default body. Mono is for what is
/// executed or measured and for the small caps labels; everything you read
/// is Inter.
abstract final class Type {
  /// A section label: small mono capitals.
  static TextStyle label(BuildContext context, {Color? color}) => TextStyle(
        fontFamily: monoFont,
        fontFamilyFallback: monoFallback,
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w500,
        color: color ?? context.colors.muted,
      );

  /// Figures and identifiers beside a title: a time, a machine, a count.
  static TextStyle meta(BuildContext context, {Color? color, double size = 12}) => TextStyle(
        fontFamily: monoFont,
        fontFamilyFallback: monoFallback,
        fontSize: size,
        color: color ?? context.colors.muted,
      );

  static TextStyle title(BuildContext context) => const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3);
}
