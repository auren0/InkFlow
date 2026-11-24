import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A quiet, theme-aware date separator used when "Group notes by date" is on.
/// The label sits between two thin lines and uses the active locale's month
/// names (for example `16 ноября 2026`).
class DateGroupHeader extends StatelessWidget {
  const DateGroupHeader({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final label = DateFormat('d MMMM y', locale).format(date);
    final lineColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, thickness: 0.7, color: lineColor)),
          Expanded(
            flex: 2,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(child: Divider(height: 1, thickness: 0.7, color: lineColor)),
        ],
      ),
    );
  }
}
