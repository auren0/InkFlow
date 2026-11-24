import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/update_provider.dart';
import 'package:inkflow/widgets/update_dialog.dart';
import 'package:provider/provider.dart';

class UpdateTile extends StatelessWidget {
  const UpdateTile({super.key});

  Future<void> _checkForUpdates(BuildContext context) async {
    final l10n = context.l10n;
    final updateProvider = context.read<UpdateProvider>();
    await updateProvider.checkForUpdates();

    if (!context.mounted) return;

    if (updateProvider.error != null) {
      _showMessage(
        context,
        l10n.t('update.checkFailed', {'error': updateProvider.error}),
      );
      return;
    }

    if (!updateProvider.hasUpdate) {
      _showMessage(context, l10n.t('update.upToDate'));
      return;
    }

    await _showUpdateDialog(context, updateProvider);
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    UpdateProvider updateProvider,
  ) {
    return showUpdateAvailableDialog(
      context: context,
      updateProvider: updateProvider,
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message, style: const TextStyle())));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final updateProvider = context.watch<UpdateProvider>();
    final update = updateProvider.update;

    final subtitle = updateProvider.isChecking
        ? l10n.t('update.checking')
        : update != null
        ? l10n.t('update.available', {'version': update.version})
        : updateProvider.currentVersion.isEmpty
        ? l10n.t('update.currentVersion')
        : l10n.t('update.currentVersionWith', {
            'version': updateProvider.currentVersion,
          });

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        FluentIcons.arrow_sync_24_regular,
        color: update != null ? theme.colorScheme.primary : null,
      ),
      title: Text(l10n.t('update.title'), style: TextStyle()),
      subtitle: Text(subtitle, style: const TextStyle()),
      trailing: updateProvider.isChecking
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : update != null
          ? IconButton(
              tooltip: update.downloadUrl.isNotEmpty
                  ? l10n.t('update.downloadTooltip')
                  : l10n.t('update.openGithub'),
              onPressed: () => _showUpdateDialog(context, updateProvider),
              icon: Icon(
                update.downloadUrl.isNotEmpty
                    ? FluentIcons.arrow_download_24_regular
                    : FluentIcons.open_24_regular,
                color: theme.colorScheme.primary,
              ),
            )
          : IconButton(
              tooltip: l10n.t('update.checkTooltip'),
              onPressed: () => _checkForUpdates(context),
              icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
            ),
      onTap: updateProvider.isChecking
          ? null
          : update != null
          ? () => _showUpdateDialog(context, updateProvider)
          : () => _checkForUpdates(context),
    );
  }
}
