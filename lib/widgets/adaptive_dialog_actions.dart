import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AdaptiveDialogButtonType { text, elevated }

class AdaptiveDialogAction {
  const AdaptiveDialogAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.type = AdaptiveDialogButtonType.text,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final AdaptiveDialogButtonType type;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
}

/// Responsive replacement for [AlertDialog.actions].
///
/// Material's [OverflowBar] stacks three buttons vertically on phones, which
/// looks broken in dialogs. This widget:
///  * keeps all buttons on one row when they genuinely fit;
///  * otherwise puts two secondary buttons on one row and the primary button
///    on a full-width row below;
///  * falls back to full-width stacked buttons on extremely narrow screens or
///    with very large system font scaling.
///
/// Labels are never shrunk. Buttons keep a minimum 44 px touch target and are
/// allowed to wrap instead of overflowing.
class AdaptiveDialogActions extends StatelessWidget {
  const AdaptiveDialogActions({
    super.key,
    required this.actions,
    this.spacing = 8,
  });

  final List<AdaptiveDialogAction> actions;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    // [AlertDialog] lays its actions out inside an [IntrinsicWidth], and
    // intrinsic dimension queries cannot traverse a [LayoutBuilder]. Derive the
    // width budget from the viewport and dialog paddings instead. The dialog
    // still grows to fit a single button row, because that row's intrinsic
    // width is what determines its width.
    final theme = Theme.of(context);
    final dialogTheme = theme.dialogTheme;
    final textDirection = Directionality.of(context);
    final insetPadding =
        dialogTheme.insetPadding ??
        const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
    final actionsPadding =
        (dialogTheme.actionsPadding ??
                const EdgeInsets.only(left: 24, right: 24, bottom: 24))
            .resolve(textDirection);
    final availableWidth = math.max(
      0.0,
      MediaQuery.sizeOf(context).width -
          insetPadding.horizontal -
          actionsPadding.horizontal,
    );
    final textScaler = MediaQuery.textScalerOf(context);

    final estimatedWidths = actions
        .map((action) => _estimateWidth(context, action, textScaler))
        .toList(growable: false);
    final totalWidth =
        estimatedWidths.fold<double>(0, (sum, width) => sum + width) +
        spacing * math.max(0, actions.length - 1);

    if (totalWidth <= availableWidth) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            _buildButton(context, actions[i], fullWidth: false),
          ],
        ],
      );
    }

    AdaptiveDialogAction? primary;
    for (final action in actions) {
      if (action.isPrimary) {
        primary = action;
        break;
      }
    }
    final secondary = actions
        .where((action) => !action.isPrimary)
        .toList(growable: false);

    // On narrow screens the recommended layout is two secondary buttons
    // side by side, with the primary action on its own full-width row.
    final halfWidth = (availableWidth - spacing) / 2;
    final secondaryFit =
        secondary.length == 2 &&
        estimatedWidths[actions.indexOf(secondary[0])] <= halfWidth &&
        estimatedWidths[actions.indexOf(secondary[1])] <= halfWidth;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (secondaryFit) ...[
          Row(
            children: [
              Expanded(
                child: _buildButton(context, secondary[0], fullWidth: true),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _buildButton(context, secondary[1], fullWidth: true),
              ),
            ],
          ),
          if (primary != null) SizedBox(height: spacing),
        ] else ...[
          for (var i = 0; i < secondary.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            _buildButton(context, secondary[i], fullWidth: true),
          ],
          if (primary != null && secondary.isNotEmpty)
            SizedBox(height: spacing),
        ],
        if (primary != null) _buildButton(context, primary, fullWidth: true),
      ],
    );
  }

  double _estimateWidth(
    BuildContext context,
    AdaptiveDialogAction action,
    TextScaler textScaler,
  ) {
    final theme = Theme.of(context);
    final baseStyle =
        theme.textTheme.labelLarge ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
    final painter = TextPainter(
      text: TextSpan(text: action.label, style: baseStyle),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 1,
    )..layout();

    final horizontalPadding =
        action.isPrimary || action.type == AdaptiveDialogButtonType.elevated
        ? 56.0
        : 40.0;
    final iconWidth = action.icon == null ? 0.0 : 24.0;

    // A small safety margin prevents a last-pixel overflow caused by platform
    // font metrics differing from the estimate.
    return painter.width + horizontalPadding + iconWidth + 4;
  }

  Widget _buildButton(
    BuildContext context,
    AdaptiveDialogAction action, {
    required bool fullWidth,
  }) {
    final minimumSize = Size(fullWidth ? double.infinity : 0, 44);
    final foreground = action.foregroundColor;
    final background = action.backgroundColor;

    final Widget child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (action.icon != null) ...[
          Icon(action.icon, size: 18),
          const SizedBox(width: 6),
        ],
        if (fullWidth)
          Expanded(
            child: Text(
              action.label,
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          )
        else
          Text(action.label, textAlign: TextAlign.center),
      ],
    );

    if (action.type == AdaptiveDialogButtonType.elevated ||
        action.isPrimary ||
        background != null) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: minimumSize,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: action.onPressed,
        child: child,
      );
    }

    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: minimumSize,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        foregroundColor: foreground,
      ),
      onPressed: action.onPressed,
      child: child,
    );
  }
}
