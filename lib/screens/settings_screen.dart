import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/note_provider.dart';
import 'package:inkflow/services/backup/backup_models.dart';
import 'package:inkflow/services/backup/backup_service.dart';
import 'package:inkflow/shared_preferences/note_settings_provider.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';
import 'package:inkflow/widgets/adaptive_dialog_actions.dart';
import 'package:inkflow/widgets/update_tile.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final noteSettings = context.watch<NoteSettingsProvider>();
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        children: [
          Text(l10n.t('settings.theme'), style: TextStyle(fontSize: 25)),
          const SizedBox(height: 10),
          _themeTile(
            context: context,
            themeProvider: themeProvider,
            theme: AppTheme.light,
            title: l10n.t('settings.light'),
            subtitle: l10n.t('settings.lightSubtitle'),
            icon: FluentIcons.weather_sunny_24_regular,
          ),
          const SizedBox(height: 5),
          _themeTile(
            context: context,
            themeProvider: themeProvider,
            theme: AppTheme.dark,
            title: l10n.t('settings.dark'),
            subtitle: l10n.t('settings.darkSubtitle'),
            icon: FluentIcons.weather_moon_24_regular,
          ),
          const SizedBox(height: 5),
          _themeTile(
            context: context,
            themeProvider: themeProvider,
            theme: AppTheme.oled,
            title: 'OLED',
            subtitle: l10n.t('settings.oledSubtitle'),
            icon: FluentIcons.dark_theme_24_regular,
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          Text(l10n.t('settings.interface'), style: TextStyle(fontSize: 25)),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(FluentIcons.color_24_regular),
            title: Text(l10n.t('settings.primaryColor')),
            subtitle: Text(l10n.t('settings.primaryColorSubtitle')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: themeProvider.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.t('common.selectColor'),
                  onPressed: () =>
                      _showPrimaryColorDialog(context, themeProvider),
                  icon: const Icon(FluentIcons.color_fill_24_regular),
                ),
              ],
            ),
          ),
          _fontTile(context, themeProvider),
          SwitchListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            secondary: const Icon(FluentIcons.text_bold_24_regular),
            title: Text(l10n.t('settings.bold')),
            subtitle: Text(l10n.t('settings.boldSubtitle')),
            value: themeProvider.boldText,
            onChanged: themeProvider.setBoldText,
          ),
          SwitchListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            secondary: const Icon(FluentIcons.calendar_ltr_24_regular),
            title: Text(l10n.t('settings.groupByDate')),
            subtitle: Text(l10n.t('settings.groupByDateSubtitle')),
            value: noteSettings.groupByDate,
            onChanged: noteSettings.setGroupByDate,
          ),
          _languageTile(context, themeProvider),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          Text(l10n.t('backup.section'), style: TextStyle(fontSize: 25)),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(FluentIcons.arrow_export_24_regular),
            title: Text(l10n.t('backup.export')),
            subtitle: Text(l10n.t('backup.exportSubtitle')),
            onTap: () => _exportAllNotes(context),
          ),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(FluentIcons.arrow_import_24_regular),
            title: Text(l10n.t('backup.import')),
            subtitle: Text(l10n.t('backup.importSubtitle')),
            onTap: () => _importNotes(context),
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          const UpdateTile(),
        ],
      ),
    );
  }

  Widget _fontTile(BuildContext context, ThemeProvider themeProvider) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(FluentIcons.text_font_24_regular),
      title: Text(l10n.t('settings.font')),
      subtitle: Text(l10n.t('settings.fontSubtitle')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            themeProvider.fontFamily,
            style: TextStyle(
              fontFamily: themeProvider.fontFamily,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            FluentIcons.chevron_right_24_regular,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: () => _showFontPicker(context, themeProvider),
    );
  }

  Widget _languageTile(BuildContext context, ThemeProvider themeProvider) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(FluentIcons.local_language_24_regular),
      title: Text(l10n.t('settings.language')),
      subtitle: Text(l10n.t('settings.languageSubtitle')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _nativeLanguageName(themeProvider.language),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            FluentIcons.chevron_right_24_regular,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: () => _showLanguagePicker(context, themeProvider),
    );
  }

  Future<void> _showFontPicker(
    BuildContext context,
    ThemeProvider themeProvider,
  ) async {
    final l10n = context.l10n;
    const fonts = [
      ThemeProvider.fontOswald,
      ThemeProvider.fontJura,
      ThemeProvider.fontNunito,
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: 10 + MediaQuery.viewPaddingOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                  child: Text(
                    l10n.t('settings.font'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                for (final font in fonts)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListTile(
                      selected: themeProvider.fontFamily == font,
                      selectedTileColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        foregroundColor: theme.colorScheme.onSurface,
                        child: Text(
                          'Aa',
                          style: TextStyle(fontFamily: font, fontSize: 14),
                        ),
                      ),
                      title: Text(
                        font,
                        style: TextStyle(
                          fontFamily: font,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        l10n.t('settings.fontPreview'),
                        style: TextStyle(fontFamily: font),
                      ),
                      trailing: themeProvider.fontFamily == font
                          ? Icon(
                              FluentIcons.checkmark_circle_24_filled,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(sheetContext, font),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await themeProvider.setFontFamily(selected);
    }
  }

  Future<void> _showLanguagePicker(
    BuildContext context,
    ThemeProvider themeProvider,
  ) async {
    final l10n = context.l10n;

    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: 10 + MediaQuery.viewPaddingOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                  child: Text(
                    l10n.t('settings.language'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                for (final language in AppLanguage.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListTile(
                      selected: themeProvider.language == language,
                      selectedTileColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: themeProvider.language == language
                            ? themeProvider.primaryColor
                            : theme.colorScheme.surfaceContainerHighest,
                        foregroundColor: themeProvider.language == language
                            ? themeProvider.onPrimaryColor
                            : theme.colorScheme.onSurface,
                        child: Text(
                          language.code.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(_nativeLanguageName(language)),
                      subtitle:
                          _nativeLanguageName(language) ==
                              _localizedLanguageName(l10n, language)
                          ? null
                          : Text(_localizedLanguageName(l10n, language)),
                      trailing: themeProvider.language == language
                          ? Icon(
                              FluentIcons.checkmark_circle_24_filled,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(sheetContext, language),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await themeProvider.setLanguage(selected);
    }
  }

  String _nativeLanguageName(AppLanguage language) {
    return switch (language) {
      AppLanguage.ru => 'Русский',
      AppLanguage.en => 'English',
      AppLanguage.de => 'Deutsch',
    };
  }

  String _localizedLanguageName(AppLocalizations l10n, AppLanguage language) {
    return switch (language) {
      AppLanguage.ru => l10n.t('settings.languageRu'),
      AppLanguage.en => l10n.t('settings.languageEn'),
      AppLanguage.de => l10n.t('settings.languageDe'),
    };
  }

  Widget _themeTile({
    required BuildContext context,
    required ThemeProvider themeProvider,
    required AppTheme theme,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = themeProvider.appTheme == theme;

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: isSelected,
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.18),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? Icon(
              FluentIcons.checkmark_24_regular,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () => themeProvider.setAppTheme(theme),
    );
  }

  Future<void> _exportAllNotes(BuildContext context) async {
    final l10n = context.l10n;
    final service = BackupService();

    try {
      final result = await _runWithProgress(
        context,
        l10n.t('backup.exporting'),
        (report) => service.exportAll(onProgress: report),
      );

      if (!context.mounted) return;

      final uri = await FilePicker.saveFile(
        dialogTitle: l10n.t('backup.exportDialogTitle'),
        fileName: result.fileName,
        bytes: result.bytes,
        mimeType: 'application/zip',
      );

      if (!context.mounted) return;
      if (uri == null) {
        _showSnack(context, l10n.t('backup.exportCancelled'));
        return;
      }

      _showSnack(
        context,
        l10n.t('backup.exported', {
          'count': result.notesCount,
          'attachments': result.attachmentsCount,
        }),
      );

      if (result.warnings.isNotEmpty) {
        await _showWarnings(
          context,
          l10n.t('backup.exportWarningsTitle'),
          result.warnings,
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, l10n.t('backup.exportFailed', {'error': error}));
    }
  }

  Future<void> _importNotes(BuildContext context) async {
    final l10n = context.l10n;
    final service = BackupService();

    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: l10n.t('backup.importDialogTitle'),
        type: FileType.custom,
        allowedExtensions: const ['zip', 'json'],
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final isJson = picked.name.toLowerCase().endsWith('.json');

      if (!context.mounted) return;
      final preview = await _runWithProgress(
        context,
        l10n.t('backup.validating'),
        (_) => service.inspect(bytes, json: isJson),
      );

      if (!context.mounted) return;
      final mode = await _showImportPreview(context, preview);
      if (mode == null || !context.mounted) return;

      if (mode == BackupImportMode.replace) {
        final confirmed = await _confirmReplace(context, preview);
        if (confirmed != true || !context.mounted) return;
      }

      final result = await _runWithProgress(
        context,
        l10n.t('backup.importing'),
        (report) => service.importPreview(preview, mode, onProgress: report),
      );

      if (!context.mounted) return;

      // Restore only known, portable preferences. Passwords, tokens and other
      // secrets are never written into settings.json.
      final settings = preview.archive.settings;
      if (settings.isNotEmpty) {
        await context.read<ThemeProvider>().applyPortableSettings(settings);
        if (!context.mounted) return;
        await context.read<NoteSettingsProvider>().applyPortableSettings(
          settings,
        );
      }

      if (!context.mounted) return;
      context.read<NoteProvider>().refreshFromStorage();
      await _showImportResult(context, result);
    } catch (error) {
      if (!context.mounted) return;
      final message = error is BackupValidationException
          ? error.message
          : l10n.t('backup.importFailed', {'error': error});
      _showSnack(context, message);
    }
  }

  Future<BackupImportMode?> _showImportPreview(
    BuildContext context,
    BackupPreview preview,
  ) {
    final l10n = context.l10n;
    var mode = BackupImportMode.merge;
    final locale = Localizations.localeOf(context).toString();
    final backupDate = DateFormat(
      'd MMMM y',
      locale,
    ).format(preview.backupDate);

    return showDialog<BackupImportMode>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);

            return AlertDialog(
              title: Text(l10n.t('backup.previewTitle'), style: TextStyle()),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.t('backup.foundNotes', {
                          'count': preview.notesCount,
                        }),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.t('backup.backupDate', {'date': backupDate}),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.t('backup.archiveDetails', {
                          'folders': preview.foldersCount,
                          'attachments': preview.attachmentsCount,
                          'version': preview.archive.manifest.appVersion,
                        }),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (preview.idConflicts > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              FluentIcons.warning_24_regular,
                              size: 18,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                preview.exactDuplicates > 0
                                    ? l10n.t('backup.conflictWarningDup', {
                                        'count': preview.idConflicts,
                                        'duplicates': preview.exactDuplicates,
                                      })
                                    : l10n.t('backup.conflictWarning', {
                                        'count': preview.idConflicts,
                                      }),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        l10n.t('backup.chooseMode'),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      _modeTile(
                        context,
                        selected: mode == BackupImportMode.merge,
                        title: l10n.t('backup.modeMerge'),
                        subtitle: l10n.t('backup.modeMergeSubtitle'),
                        icon: FluentIcons.merge_24_regular,
                        onTap: () =>
                            setDialogState(() => mode = BackupImportMode.merge),
                      ),
                      _modeTile(
                        context,
                        selected: mode == BackupImportMode.replace,
                        title: l10n.t('backup.modeReplace'),
                        subtitle: l10n.t('backup.modeReplaceSubtitle'),
                        icon: FluentIcons.arrow_sync_24_regular,
                        onTap: () => setDialogState(
                          () => mode = BackupImportMode.replace,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: AdaptiveDialogActions(
                    actions: [
                      AdaptiveDialogAction(
                        label: l10n.t('common.cancel'),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                      AdaptiveDialogAction(
                        label: l10n.t('backup.continue'),
                        isPrimary: true,
                        onPressed: () => Navigator.pop(dialogContext, mode),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _modeTile(
    BuildContext context, {
    required bool selected,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: selected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.14),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(
              FluentIcons.checkmark_circle_24_filled,
              color: theme.colorScheme.primary,
            )
          : Icon(
              FluentIcons.circle_24_regular,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      onTap: onTap,
    );
  }

  Future<bool?> _confirmReplace(BuildContext context, BackupPreview preview) {
    final l10n = context.l10n;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          title: Text(l10n.t('backup.replaceTitle'), style: TextStyle()),
          content: Text(
            l10n.t('backup.replaceWarning', {
              'existing': preview.existingNotesCount,
              'imported': preview.notesCount,
            }),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: AdaptiveDialogActions(
                actions: [
                  AdaptiveDialogAction(
                    label: l10n.t('common.cancel'),
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                  AdaptiveDialogAction(
                    label: l10n.t('backup.replaceConfirm'),
                    isPrimary: true,
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    onPressed: () => Navigator.pop(dialogContext, true),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImportResult(
    BuildContext context,
    BackupImportResult result,
  ) async {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                FluentIcons.checkmark_circle_24_filled,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t('backup.importComplete'),
                  style: TextStyle(),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('backup.importedCount', {
                    'count': result.importedNotes,
                  }),
                ),
                if (result.skippedDuplicates > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.t('backup.skippedDuplicates', {
                      'count': result.skippedDuplicates,
                    }),
                  ),
                ],
                if (result.reassignedIds > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.t('backup.reassignedIds', {
                      'count': result.reassignedIds,
                    }),
                  ),
                ],
                if (result.restoredAttachments > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.t('backup.restoredAttachments', {
                      'count': result.restoredAttachments,
                    }),
                  ),
                ],
                if (result.warnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...result.warnings.map(
                    (warning) => Text(
                      warning,
                      style: TextStyle(color: theme.colorScheme.tertiary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: AdaptiveDialogActions(
                actions: [
                  AdaptiveDialogAction(
                    label: l10n.t('common.done'),
                    isPrimary: true,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showWarnings(
    BuildContext context,
    String title,
    List<String> warnings,
  ) {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          title: Text(title, style: TextStyle()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: warnings
                  .map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        warning,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: AdaptiveDialogActions(
                actions: [
                  AdaptiveDialogAction(
                    label: l10n.t('common.done'),
                    isPrimary: true,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<T> _runWithProgress<T>(
    BuildContext context,
    String message,
    Future<T> Function(void Function(double) report) task,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = ValueNotifier<double?>(null);

    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double?>(
                  valueListenable: progress,
                  builder: (context, value, _) => value == null
                      ? const CircularProgressIndicator()
                      : LinearProgressIndicator(value: value),
                ),
                const SizedBox(height: 18),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );

    try {
      return await task((value) => progress.value = value.clamp(0, 1));
    } finally {
      if (navigator.mounted) navigator.pop();
      await dialogFuture;
      progress.dispose();
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message, style: const TextStyle())));
  }

  Future<void> _showPrimaryColorDialog(
    BuildContext context,
    ThemeProvider themeProvider,
  ) async {
    final l10n = context.l10n;
    Color tempColor = themeProvider.primaryColor;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(l10n.t('settings.primaryColorTitle')),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerAreaBorderRadius: BorderRadius.circular(10),
              pickerColor: tempColor,
              onColorChanged: (Color color) {
                tempColor = color;
              },
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: AdaptiveDialogActions(
                actions: [
                  AdaptiveDialogAction(
                    label: l10n.t('common.reset'),
                    onPressed: () async {
                      await themeProvider.resetPrimaryColor();
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                  ),
                  AdaptiveDialogAction(
                    label: l10n.t('common.cancel'),
                    type: AdaptiveDialogButtonType.elevated,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onSurface,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                  AdaptiveDialogAction(
                    label: l10n.t('common.choose'),
                    isPrimary: true,
                    backgroundColor: themeProvider.primaryColor,
                    foregroundColor: themeProvider.onPrimaryColor,
                    onPressed: () async {
                      await themeProvider.setPrimaryColor(tempColor);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
