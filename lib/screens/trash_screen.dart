import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/note_provider.dart';
import 'package:inkflow/services/note_content.dart';
import 'package:inkflow/services/note_sorting.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';
import 'package:provider/provider.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final trashNotes = noteProvider.trashNotes;
    final trashFolders = noteProvider.trashFolders;
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelStyle: TextStyle(),
            unselectedLabelStyle: TextStyle(),
            labelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(
                text: l10n.t('trash.notes'),
                icon: Icon(FluentIcons.note_24_regular),
              ),
              Tab(
                text: l10n.t('trash.folders'),
                icon: Icon(FluentIcons.folder_24_regular),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                trashNotes.isEmpty
                    ? Center(
                        child: Text(
                          l10n.t('trash.noNotes'),
                          style: TextStyle(),
                        ),
                      )
                    : ListView.separated(
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          10 + bottomInset,
                        ),
                        itemCount: trashNotes.length,
                        itemBuilder: (context, index) {
                          final note = trashNotes[index];
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
                              note.usesCustomTextColor &&
                                  note.textColorValue != null
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
                                    FluentIcons
                                        .arrow_counterclockwise_24_regular,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    noteProvider.restoreNoteFromTrash(note);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.t('trash.restored'),
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
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                          l10n.t('trash.deleteForever'),
                                          style: TextStyle(),
                                        ),
                                        content: Text(
                                          l10n.t('trash.confirmDeleteNote'),
                                          style: TextStyle(),
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16.0,
                                                    horizontal: 25.0,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              side: BorderSide(
                                                color: Colors.green,
                                                width: 2,
                                              ),
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text(
                                              l10n.t('common.cancel'),
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16.0,
                                                    horizontal: 25.0,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                            onPressed: () {
                                              noteProvider.deleteNoteForever(
                                                note,
                                              );
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l10n.t(
                                                      'trash.noteDeletedForever',
                                                    ),
                                                    style: TextStyle(),
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              l10n.t('common.delete'),
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                trashFolders.isEmpty
                    ? Center(
                        child: Text(
                          l10n.t('trash.noFolders'),
                          style: TextStyle(),
                        ),
                      )
                    : ListView.separated(
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          10 + bottomInset,
                        ),
                        itemCount: trashFolders.length,
                        itemBuilder: (context, index) {
                          final folder = trashFolders[index];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            // tileColor: Colors.yellow,
                            leading: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(folder.colorValue),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              folder.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamilyFallback: ['Apple'],
                                // color: Colors.black,
                                // color: note.textColorValue != null
                                //     ? Color(note.textColorValue!)
                                //     : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    FluentIcons
                                        .arrow_counterclockwise_24_regular,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    noteProvider.restoreFolderFromTrash(folder);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.t('trash.restored'),
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
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                          l10n.t('trash.deleteForever'),
                                          style: TextStyle(),
                                        ),
                                        content: Text(
                                          l10n.t('trash.confirmDeleteFolder'),
                                          style: TextStyle(),
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16.0,
                                                    horizontal: 25.0,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              side: BorderSide(
                                                color: Colors.green,
                                                width: 2,
                                              ),
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: Text(
                                              l10n.t('common.cancel'),
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16.0,
                                                    horizontal: 25.0,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                            onPressed: () {
                                              noteProvider.deleteFolderForever(
                                                folder,
                                              );
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l10n.t(
                                                      'trash.folderDeletedForever',
                                                    ),
                                                    style: TextStyle(),
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              l10n.t('common.delete'),
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
