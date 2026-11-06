import 'package:flutter/material.dart';
import 'package:note_app/providers/note_provider.dart';
import 'package:provider/provider.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final archive = noteProvider.archive;

    return Scaffold(
      body: archive.isEmpty
          ? const Center(
              child: Text(
                'Архив пустой',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
            )
          : ListView.separated(
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
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
                      fontFamily: 'Jura',
                      fontFamilyFallback: const ['Apple'],
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    note.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Jura',
                      fontFamilyFallback: const ['Apple'],
                      color: textColor.withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.restore, color: Colors.blue),
                        onPressed: () {
                          noteProvider.restoreNoteFromTrash(note);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Заметка восстановлена',
                                style: TextStyle(fontFamily: 'Oswald'),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () {
                          noteProvider.moveNoteToTrash(note);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Заметка перемещена в корзину',
                                style: TextStyle(fontFamily: 'Oswald'),
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
