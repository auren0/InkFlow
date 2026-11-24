import 'package:flutter/material.dart';

/// Applies the app-wide font family and optional bold weight to a [TextTheme].
///
/// Some Material text styles have a `null` font weight. [TextStyle.apply] with
/// a non-zero `fontWeightDelta` asserts in that case, so the weight is resolved
/// explicitly here.
TextTheme applyAppFont(
  TextTheme base, {
  required String family,
  required bool bold,
}) {
  TextStyle? apply(TextStyle? style) {
    if (style == null) return null;

    final weight = style.fontWeight;
    final adjustedWeight = !bold
        ? weight
        : FontWeight.values.firstWhere(
            (candidate) =>
                candidate.value ==
                ((weight ?? FontWeight.w400).value + 300).clamp(100, 900),
            orElse: () => FontWeight.w900,
          );

    return style.copyWith(fontFamily: family, fontWeight: adjustedWeight);
  }

  return TextTheme(
    displayLarge: apply(base.displayLarge),
    displayMedium: apply(base.displayMedium),
    displaySmall: apply(base.displaySmall),
    headlineLarge: apply(base.headlineLarge),
    headlineMedium: apply(base.headlineMedium),
    headlineSmall: apply(base.headlineSmall),
    titleLarge: apply(base.titleLarge),
    titleMedium: apply(base.titleMedium),
    titleSmall: apply(base.titleSmall),
    bodyLarge: apply(base.bodyLarge),
    bodyMedium: apply(base.bodyMedium),
    bodySmall: apply(base.bodySmall),
    labelLarge: apply(base.labelLarge),
    labelMedium: apply(base.labelMedium),
    labelSmall: apply(base.labelSmall),
  );
}
