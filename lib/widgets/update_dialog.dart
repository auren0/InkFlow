import 'package:flutter/material.dart';
import 'package:note_app/providers/update_provider.dart';

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
  final action = await showDialog<_UpdateAction>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Доступна версия ${update.version}',
          style: const TextStyle(fontFamily: 'Oswald'),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Установлена версия ${updateProvider.currentVersion}',
                  style: const TextStyle(fontFamily: 'Oswald'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Вы можете скачать новую версию с GitHub Releases '
                  'и установить её поверх текущей.',
                  style: TextStyle(fontFamily: 'Oswald'),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Что нового:',
                    style: TextStyle(
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(notes, style: const TextStyle(fontFamily: 'Oswald')),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _UpdateAction.later),
            child: const Text('Позже', style: TextStyle(fontFamily: 'Oswald')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _UpdateAction.openRelease),
            child: const Text(
              'Открыть на GitHub',
              style: TextStyle(fontFamily: 'Oswald'),
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _UpdateAction.download),
            child: const Text(
              'Скачать обновление',
              style: TextStyle(fontFamily: 'Oswald'),
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
            'Не удалось открыть ссылку: $e',
            style: const TextStyle(fontFamily: 'Oswald'),
          ),
        ),
      );
    }
  }
}
