import 'dart:io';

import 'package:flutter/material.dart';
import 'package:note_app/services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateTile extends StatefulWidget {
  const UpdateTile({super.key});

  @override
  State<UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<UpdateTile> {
  final UpdateService _updateService = UpdateService();

  String _currentVersion = '';
  bool _checking = false;
  bool _downloading = false;
  double _downloadProgress = 0;

  bool get _busy => _checking || _downloading;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _currentVersion = info.version);
      }
    } catch (_) {
      // Версия недоступна — не мешаем пользователю пользоваться настройками.
    }
  }

  Future<void> _checkForUpdates() async {
    if (_busy) return;

    setState(() => _checking = true);
    try {
      final update = await _updateService.checkForUpdate();
      if (!mounted) return;

      if (update == null) {
        _showMessage('У вас последняя версия InkFlow');
        return;
      }

      await _showUpdateDialog(update);
    } catch (e) {
      if (mounted) {
        _showMessage('Не удалось проверить обновления: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo update) async {
    final notes = update.releaseNotes;
    final shouldInstall = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
                    'Установлена версия $_currentVersion',
                    style: const TextStyle(fontFamily: 'Oswald'),
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
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Позже',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Скачать и установить',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
            ),
          ],
        );
      },
    );

    if (shouldInstall == true) {
      await _downloadAndInstall(update);
    }
  }

  Future<void> _downloadAndInstall(UpdateInfo update) async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      final installer = await _updateService.downloadUpdate(
        update,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );

      if (!mounted) return;

      _showMessage('Запускаем установку обновления…');
      await _updateService.installUpdate(installer);
    } catch (e) {
      if (mounted) {
        _showMessage('Не удалось установить обновление: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

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
    final percent = (_downloadProgress * 100).clamp(0, 100).round();
    final subtitle = _downloading
        ? 'Скачивание обновления… $percent%'
        : _checking
        ? 'Проверка обновлений…'
        : _currentVersion.isEmpty
        ? 'Текущая версия'
        : 'Текущая версия: $_currentVersion';

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.system_update_alt_rounded),
      title: const Text('Обновления', style: TextStyle(fontFamily: 'Oswald')),
      subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Oswald')),
      trailing: _downloading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            )
          : _checking
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : IconButton(
              tooltip: 'Проверить обновления',
              onPressed: _checkForUpdates,
              icon: const Icon(Icons.refresh_rounded),
            ),
      onTap: _busy ? null : _checkForUpdates,
    );
  }
}
