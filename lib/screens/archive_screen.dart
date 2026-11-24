import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/note_provider.dart';
import 'package:inkflow/services/note_content.dart';
import 'package:inkflow/services/note_sorting.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';
import 'package:provider/provider.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final archive = noteProvider.archive;
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: archive.isEmpty
          ? Center(child: Text(l10n.t('archive.empty'), style: TextStyle()))
          : ListView.separated(
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
              itemCount: noteProvider.archive.length,
              itemBuilder: (context, index) {
                final note = noteProvider.archive[index];
                final theme = Theme.of(context);
                final customBackground =
                    note.usesCustomBackground &&
                        note.backgroundColorValue != null
                    ? Color(note.backgroundColorValue!)
                    : null;
                final defaultTextColor =
                    customBackground != null &&
                        customBackground.computeLuminance() > 0.5
                    ? Colors.black
                    : theme.colorScheme.onSurface;
                final textColor =
                    note.usesCustomTextColor && note.textColorValue != null
                    ? Color(note.textColorValue!)
                    : defaultTextColor;

                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  tileColor:
                      customBackground ??
                      theme.colorScheme.surfaceContainerHigh,
                  title: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamilyFallback: const ['Apple'],
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.t('note.createdAt', {
                          'date': formatNoteDateTime(
                            context,
                            note.createdAt ?? DateTime.now(),
                          ),
                        }),
                        style: TextStyle(
                          fontFamily: themeProvider.fontFamily,
                          fontSize: 11,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        NoteContent.plainText(note.content),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamilyFallback: const ['Apple'],
                          color: textColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          FluentIcons.arrow_counterclockwise_24_regular,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          noteProvider.restoreNoteFromTrash(note);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.t('archive.restored'),
                                style: TextStyle(),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          FluentIcons.delete_24_regular,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          noteProvider.moveNoteToTrash(note);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.t('archive.movedToTrash'),
                                style: TextStyle(),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
