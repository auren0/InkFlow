import 'dart:io';

import 'package:flutter/material.dart';
import 'package:note_app/providers/update_provider.dart';
import 'package:note_app/widgets/update_dialog.dart';
import 'package:provider/provider.dart';

class UpdateTile extends StatelessWidget {
  const UpdateTile({super.key});

  Future<void> _checkForUpdates(BuildContext context) async {
    final updateProvider = context.read<UpdateProvider>();
    await updateProvider.checkForUpdates();

    if (!context.mounted) return;

    if (updateProvider.error != null) {
      _showMessage(
        context,
        'Не удалось проверить обновления: ${updateProvider.error}',
      );
      return;
    }

    if (!updateProvider.hasUpdate) {
      _showMessage(context, 'У вас последняя версия InkFlow');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Oswald')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final updateProvider = context.watch<UpdateProvider>();
    final update = updateProvider.update;

    final subtitle = updateProvider.isChecking
        ? 'Проверка обновлений…'
        : update != null
        ? 'Доступна версия ${update.version}. Нажмите, чтобы скачать.'
        : updateProvider.currentVersion.isEmpty
        ? 'Текущая версия'
        : 'Текущая версия: ${updateProvider.currentVersion}';

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        Icons.system_update_alt_rounded,
        color: update != null ? theme.colorScheme.primary : null,
      ),
      title: const Text('Обновления', style: TextStyle(fontFamily: 'Oswald')),
      subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Oswald')),
      trailing: updateProvider.isChecking
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : update != null
          ? IconButton(
              tooltip: 'Скачать обновление',
              onPressed: () => _showUpdateDialog(context, updateProvider),
              icon: Icon(
                Icons.download_rounded,
                color: theme.colorScheme.primary,
              ),
            )
          : IconButton(
              tooltip: 'Проверить обновления',
              onPressed: () => _checkForUpdates(context),
              icon: const Icon(Icons.refresh_rounded),
            ),
      onTap: updateProvider.isChecking
          ? null
          : update != null
          ? () => _showUpdateDialog(context, updateProvider)
          : () => _checkForUpdates(context),
    );
  }
}
