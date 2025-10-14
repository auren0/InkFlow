import 'package:flutter/material.dart';
import 'package:note_app/providers/note_provider.dart';
import 'package:provider/provider.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final trashNotes = noteProvider.trashNotes;
    final trashFolders = noteProvider.trashFolders;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelStyle: TextStyle(fontFamily: 'Oswald'),
            unselectedLabelStyle: TextStyle(fontFamily: 'Oswald'),
            labelColor: Colors.yellow,
            indicatorColor: Colors.yellow,
            tabs: [
              Tab(text: 'Заметки', icon: Icon(Icons.note)),
              Tab(text: 'Папки', icon: Icon(Icons.folder)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                trashNotes.isEmpty
                    ? const Center(
                        child: Text(
                          'Заметок в корзине нет',
                          style: TextStyle(fontFamily: 'Oswald'),
                        ),
                      )
                    : ListView.separated(
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                        itemCount: trashNotes.length,
                        itemBuilder: (context, index) {
                          final note = trashNotes[index];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            // tileColor: Colors.yellow,
                            tileColor: note.backgroundColorValue != null
                                ? Color(note.backgroundColorValue!)
                                : Colors.yellow,
                            title: Text(
                              note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Jura',
                                fontFamilyFallback: ['Apple'],
                                // color: Colors.black,
                                color: note.textColorValue != null
                                    ? Color(note.textColorValue!)
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              note.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Jura',
                                fontFamilyFallback: ['Apple'],
                                color: Colors.black,
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
                                          style: TextStyle(
                                            fontFamily: 'Oswald',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Удалить навсегда',
                                          style: TextStyle(
                                            fontFamily: 'Oswald',
                                          ),
                                        ),
                                        content: const Text(
                                          'Вы действительно хотите удалить заметку навсегда?',
                                          style: TextStyle(
                                            fontFamily: 'Oswald',
                                          ),
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
                                              "Отмена",
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontFamily: 'Oswald',
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
                                                  content: const Text(
                                                    'Заметка удалена навсегда',
                                                    style: TextStyle(
                                                      fontFamily: 'Oswald',
                                                    ),
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
                    ? const Center(
                        child: Text(
                          'Папок в корзине нет',
                          style: TextStyle(fontFamily: 'Oswald'),
                        ),
                      )
                    : ListView.separated(
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
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
                                fontFamily: 'Jura',
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
                                  icon: Icon(Icons.restore, color: Colors.blue),
                                  onPressed: () {
                                    noteProvider.restoreFolderFromTrash(folder);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Заметка восстановлена',
                                          style: TextStyle(
                                            fontFamily: 'Oswald',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Удалить навсегда',
                                          style: TextStyle(
                                            fontFamily: 'Oswald',
                                          ),
                                        ),
                                        content: const Text(
                                          'Вы действительно хотите удалить папку навсегда?',
                                          style: TextStyle(
                                            fontFamily: 'Oswald',
                                          ),
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
                                              "Отмена",
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontFamily: 'Oswald',
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
                                                  content: const Text(
                                                    'Папка удалена навсегда',
                                                    style: TextStyle(
                                                      fontFamily: 'Oswald',
                                                    ),
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
