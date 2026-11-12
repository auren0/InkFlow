import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:note_app/hive_models/save_note.dart';
import 'package:note_app/providers/note_provider.dart';
import 'package:note_app/screens/create_note_screen.dart';
import 'package:note_app/shared_preferences/theme_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // List<Note> _notes = [];

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    // final notes = noteProvider.notes;
    final notes = noteProvider.notes
        .where((note) => note.folderId == null)
        .toList();

    return Scaffold(
      body: notes.isEmpty
          ? const Center(
              child: Text(
                'У вас пока нет заметок',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
            )
          : Builder(
              builder: (context) {
                // Оставляем место снизу, чтобы последние заметки не перекрывались
                // кнопкой "Создать заметку".
                final bottomInset = MediaQuery.of(context).padding.bottom;
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 88 + bottomInset),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return NoteCard(note: note, noteProvider: noteProvider);
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const CreateNoteScreen()),
          );
        },
        backgroundColor: themeProvider.primaryColor,
        icon: Icon(Icons.create, color: themeProvider.onPrimaryColor),
        label: Text(
          'Создать заметку',
          style: TextStyle(
            fontFamily: 'Oswald',
            color: themeProvider.onPrimaryColor,
          ),
        ),
      ),
    );
  }
}

class NoteCard extends StatefulWidget {
  final SaveNote note;
  final NoteProvider noteProvider;

  const NoteCard({super.key, required this.note, required this.noteProvider});

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  Color borderColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final folders = noteProvider.folders;
    final note = widget.note;
    final hasAudio = note.audioNotes?.isNotEmpty ?? false;
    final hasAttachments = note.attachments?.isNotEmpty ?? false;
    final cardColor =
        note.usesCustomBackground && note.backgroundColorValue != null
        ? Color(note.backgroundColorValue!)
        : null;
    final defaultTextColor =
        cardColor != null && cardColor.computeLuminance() > 0.5
        ? Colors.black
        : theme.colorScheme.onSurface;
    final textColor = note.usesCustomTextColor && note.textColorValue != null
        ? Color(note.textColorValue!)
        : defaultTextColor;
    final title = note.title.trim();
    final displayTitle = title.isNotEmpty
        ? note.title
        : hasAudio && hasAttachments
        ? 'Аудио и файлы'
        : hasAudio
        ? 'Аудиозаметка'
        : hasAttachments
        ? 'Файлы'
        : 'Без названия';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          await Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => CreateNoteScreen(note: widget.note),
            ),
          );
        },
        onLongPress: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              title: const Text(
                'Выберите вариант',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
              actions: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16.0,
                            horizontal: 25.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(color: Colors.green, width: 2),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          "Отмена",
                          style: TextStyle(
                            color: Colors.green,
                            fontFamily: 'Oswald',
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16.0,
                            horizontal: 25.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: Colors.brown,
                        ),
                        onPressed: () {
                          widget.noteProvider.addToArchive(widget.note);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Заметка перемещена в архив',
                                style: TextStyle(fontFamily: 'Oswald'),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          "Архивировать",
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Oswald',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (widget.note.folderId != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16.0,
                              horizontal: 25.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.teal,
                          ),
                          onPressed: () {
                            widget.noteProvider.removeNoteFromFolder(
                              widget.note,
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Заметка перемещена на рабочий стол',
                                  style: TextStyle(fontFamily: 'Oswald'),
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            "Переместить на рабочий стол",
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Oswald',
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16.0,
                            horizontal: 25.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: themeProvider.primaryColor,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          final isInFolder = widget.note.folderId != null;
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            builder: (context) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[400],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (isInFolder) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.desktop_windows_outlined,
                                        color: Colors.teal,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Text(
                                        'Убрать из папки (на рабочий стол)',
                                        style: TextStyle(
                                          fontFamily: 'Oswald',
                                          color: Colors.teal,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onTap: () {
                                        noteProvider.removeNoteFromFolder(
                                          widget.note,
                                        );
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Заметка перемещена на рабочий стол',
                                              style: TextStyle(
                                                fontFamily: 'Oswald',
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const Divider(indent: 16, endIndent: 16),
                                ],
                                if (folders.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 24.0,
                                      horizontal: 16.0,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'У вас пока нет папок',
                                        style: TextStyle(
                                          fontFamily: 'Oswald',
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Flexible(
                                    child: SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.5,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: folders.length,
                                        itemBuilder: (context, index) {
                                          final folder = folders[index];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                            ),
                                            child: ListTile(
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
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              title: Text(
                                                folder.title,
                                                style: const TextStyle(
                                                  fontFamily: 'Oswald',
                                                ),
                                              ),
                                              onTap: () {
                                                noteProvider.addNoteToFolder(
                                                  widget.note,
                                                  folder,
                                                );
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Заметка перемещена в папку ${folder.title}',
                                                      style: const TextStyle(
                                                        fontFamily: 'Oswald',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                        child: Text(
                          widget.note.folderId != null
                              ? "Переместить в папку"
                              : "Добавить в папку",
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Oswald',
                            color: themeProvider.onPrimaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16.0,
                            horizontal: 25.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () {
                          widget.noteProvider.moveNoteToTrash(widget.note);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Заметка перемещена в корзину',
                                style: TextStyle(fontFamily: 'Oswald'),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          "Удалить",
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Oswald',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayTitle,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Jura',
                  fontFamilyFallback: const ['Apple'],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontStyle: title.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  note.content.isEmpty && (hasAudio || hasAttachments)
                      ? 'Без текста'
                      : note.content,
                  style: TextStyle(
                    color: note.content.isEmpty
                        ? textColor.withValues(alpha: 0.65)
                        : textColor,
                    fontFamily: 'Jura',
                    fontFamilyFallback: const ['Apple'],
                    fontSize: 14,
                    fontStyle: note.content.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasAudio || hasAttachments) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (hasAudio)
                      _mediaBadge(
                        Icons.mic_none_rounded,
                        '${note.audioNotes!.length}',
                        textColor,
                      ),
                    if (hasAttachments)
                      _mediaBadge(
                        Icons.attach_file_rounded,
                        '${note.attachments!.length}',
                        textColor,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaBadge(IconData icon, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(fontFamily: 'Oswald', fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}
