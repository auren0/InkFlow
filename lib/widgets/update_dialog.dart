import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/update_provider.dart';
import 'package:inkflow/widgets/adaptive_dialog_actions.dart';

enum _UpdateAction { download, openRelease, later }

/// Показывает предупреждение о новой версии с кнопками для перехода
/// на GitHub Releases и скачивания установщика в браузере.
Future<void> showUpdateAvailableDialog({
  required BuildContext context,
  required UpdateProvider updateProvider,
}) async {
  final update = updateProvider.update;
  if (update == null) return;

  final notes = update.releaseNotes;
  final l10n = context.l10n;
  final action = await showDialog<_UpdateAction>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.t('update.availableTitle', {'version': update.version}),
          style: const TextStyle(),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.t('update.installed', {
                'version': updateProvider.currentVersion,
              }),
              style: const TextStyle(),
            ),
            const SizedBox(height: 10),
            Text(l10n.t('update.description'), style: TextStyle()),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                l10n.t('update.whatsNew'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(notes, style: const TextStyle()),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: AdaptiveDialogActions(
              actions: [
                AdaptiveDialogAction(
                  label: l10n.t('common.later'),
                  onPressed: () =>
                      Navigator.pop(dialogContext, _UpdateAction.later),
                ),
                AdaptiveDialogAction(
                  label: l10n.t('update.openGithub'),
                  icon: FluentIcons.open_24_regular,
                  onPressed: () =>
                      Navigator.pop(dialogContext, _UpdateAction.openRelease),
                ),
                AdaptiveDialogAction(
                  label: update.downloadUrl.isNotEmpty
                      ? l10n.t('update.download')
                      : l10n.t('update.openGithub'),
                  icon: update.downloadUrl.isNotEmpty
                      ? FluentIcons.arrow_download_24_regular
                      : FluentIcons.open_24_regular,
                  isPrimary: true,
                  onPressed: () =>
                      Navigator.pop(dialogContext, _UpdateAction.download),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  if (action == null || action == _UpdateAction.later) {
    await updateProvider.dismissUpdate();
    return;
  }

  try {
    if (action == _UpdateAction.download) {
      await updateProvider.openDownload();
    } else {
      await updateProvider.openReleasePage();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('update.openFailed', {'error': e}),
            style: const TextStyle(),
          ),
        ),
      );
    }
  }
}
