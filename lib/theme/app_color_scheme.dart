import 'package:flutter/material.dart';

/// Returns a primary color that stays readable against the current background.
///
/// The user picks the interface color directly, so it is kept as-is whenever it
/// has enough contrast. Very light colors on a light theme are slightly
/// darkened, and very dark colors on a dark theme are slightly lightened.
Color readablePrimaryColor(Color color, Brightness brightness) {
  final luminance = color.computeLuminance();

  if (brightness == Brightness.light && luminance > 0.55) {
    return Color.lerp(color, Colors.black, 0.55)!;
  }

  if (brightness == Brightness.dark && luminance < 0.10) {
    return Color.lerp(color, Colors.white, 0.55)!;
  }

  return color;
}

/// Builds the app color scheme while keeping the user's interface color as the
/// primary color instead of letting [ColorScheme.fromSeed] derive a tinted one.
///
/// For example, a white seed used to produce a cyan-tinted primary, which made
/// selected list tiles and other accent text look blue. The primary color is now
/// the chosen color (adjusted only when needed for contrast).
ColorScheme buildAppColorScheme({
  required Color seedColor,
  required Brightness brightness,
}) {
  final primary = readablePrimaryColor(seedColor, brightness);
  final onPrimary = primary.computeLuminance() > 0.5
      ? Colors.black
      : Colors.white;

  return ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  ).copyWith(primary: primary, onPrimary: onPrimary);
}

/// Switch colors that never fall back to the cyan-tinted `primaryContainer`
/// generated from a white seed.
///
/// Material 3 uses `primaryContainer` for the thumb while it is hovered,
/// pressed or focused. With a white interface color that container is
/// blue/cyan, which looks out of place. The hovered thumb is now a shade
/// between the track and its normal thumb color instead.
SwitchThemeData buildAppSwitchTheme(ColorScheme scheme) {
  return SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return null;

      final selected = states.contains(WidgetState.selected);
      final interacting =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused);

      if (selected) {
        return interacting
            ? Color.lerp(scheme.onPrimary, scheme.primary, 0.3)
            : scheme.onPrimary;
      }

      return interacting ? scheme.onSurface.withValues(alpha: 0.8) : null;
    }),
  );
}
