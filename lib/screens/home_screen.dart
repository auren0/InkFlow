import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:note_app/hive_models/save_note.dart';
import 'package:note_app/providers/note_provider.dart';
import 'package:note_app/screens/create_note_screen.dart';
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
          : Padding(
              padding: const EdgeInsets.all(8.0),
              // child: GridView.builder(
              //   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              //     crossAxisCount: 2,
              //     crossAxisSpacing: 5,
              //     mainAxisSpacing: 5,
              //     childAspectRatio: 1,
              //   ),
              //   itemCount: notes.length,
              //   itemBuilder: (context, index) {
              //     final note = notes[index];
              //     return NoteCard(note: note, noteProvider: noteProvider);
              //   },
              // ),
              child: GridView.builder(
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
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => CreateNoteScreen()),
          );

          if (result != null && result is SaveNote) {
            noteProvider.addNote(result);
            // setState(() {
            //   _notes.add(result);
            // });
          }
        },
        backgroundColor: Colors.yellow,
        icon: const Icon(Icons.create, color: Colors.black),
        label: const Text(
          'Создать заметку',
          style: TextStyle(fontFamily: 'Oswald', color: Colors.black),
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
    final folders = noteProvider.folders;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      color: widget.note.backgroundColorValue != null
          ? Color(widget.note.backgroundColorValue!)
          : Colors.yellow,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          final result = await Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => CreateNoteScreen(note: widget.note),
            ),
          );
          if (result != null && result is SaveNote) {
            widget.noteProvider.updateNote(widget.note, result);
          }
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
                          backgroundColor: Colors.yellow,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            shape: RoundedRectangleBorder(
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
                                              style: TextStyle(
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
                                                    style: TextStyle(
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
                          "Добавить в папку",
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Oswald',
                            color: Colors.black,
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
                widget.note.title,
                style: TextStyle(
                  color: widget.note.textColorValue != null
                      ? Color(widget.note.textColorValue!)
                      : Colors.black,
                  fontFamily: 'Jura',
                  fontFamilyFallback: ['Apple'],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  widget.note.content,
                  style: TextStyle(
                    color: widget.note.textColorValue != null
                        ? Color(widget.note.textColorValue!)
                        : Colors.black,
                    fontFamily: 'Jura',
                    fontFamilyFallback: ['Apple'],
                    fontSize: 14,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
