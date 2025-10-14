import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:note_app/hive_models/save_folder.dart';
import 'package:note_app/providers/note_provider.dart';
import 'package:note_app/shared_preferences/theme_provider.dart';
import 'package:provider/provider.dart';

class CreateFolderScreen extends StatefulWidget {
  final SaveFolder? folder;

  const CreateFolderScreen({super.key, this.folder});

  @override
  State<CreateFolderScreen> createState() => _CreateFolderScreenState();
}

class _CreateFolderScreenState extends State<CreateFolderScreen> {
  // final TextEditingController _folderTitleController = TextEditingController();
  // Color _selectedColor = Colors.blue;

  late TextEditingController _folderTitleController;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _folderTitleController = TextEditingController(
      text: widget.folder?.title ?? '',
    );
    _selectedColor = widget.folder != null
        ? Color(widget.folder!.colorValue)
        : Colors.yellow;
  }

  @override
  Widget build(BuildContext context) {
    // final themeProvider = context.watch<ThemeProvider>();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Создать папку',
          style: TextStyle(fontFamily: 'Oswald'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20.0),
                  foregroundColor: Colors.yellow,
                  // backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.yellow, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Color tempColor = _selectedColor;

                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => AlertDialog(
                      title: const Text(
                        'Выберите цвет для выбранного дня',
                        style: TextStyle(fontFamily: 'Oswald'),
                      ),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: tempColor,
                          onColorChanged: (Color color) {
                            tempColor = color;
                          },
                          pickerAreaBorderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16.0,
                              horizontal: 25.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(
                              color: Colors.yellow[600]!,
                              width: 2,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Отмена",
                            style: TextStyle(
                              color: Colors.yellow[600]!,
                              fontFamily: 'Oswald',
                              fontSize: 18,
                            ),
                          ),
                        ),
                        ElevatedButton(
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
                            setState(() {
                              _selectedColor = tempColor;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Выбрать",
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Oswald',
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  'Выбрать цвет тега',
                  style: TextStyle(
                    color: themeProvider.isDark ? Colors.yellow : Colors.black,
                    fontFamily: 'Oswald',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  selectionColor: Colors.yellow.withValues(alpha: 0.3),
                  selectionHandleColor: Colors.yellow,
                ),
              ),
              child: TextField(
                controller: _folderTitleController,
                cursorColor: Colors.yellow,
                decoration: InputDecoration(
                  floatingLabelStyle: TextStyle(
                    fontFamily: 'Oswald',
                    color: themeProvider.isDark ? Colors.yellow : Colors.black,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.yellow, width: 2),
                    // borderRadius: BorderRadius.circular(10),
                  ),
                  focusColor: Colors.yellow,
                  border: OutlineInputBorder(),
                  label: const Text(
                    'Название',
                    style: TextStyle(fontFamily: 'Oswald'),
                  ),
                  hint: const Text(
                    'Введите название папки',
                    style: TextStyle(fontFamily: 'Oswald'),
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Jura',
                  fontFamilyFallback: ['Apple'],
                ),
              ),
            ),
            const SizedBox(height: 45),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20.0),
                  backgroundColor: Colors.yellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final title = _folderTitleController.text;
                  if (title.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Введите назание папки!',
                          style: TextStyle(fontFamily: 'Oswald'),
                        ),
                      ),
                    );
                    return;
                  }

                  if (widget.folder == null) {
                    final folder = SaveFolder(
                      title: title,
                      colorValue: _selectedColor.toARGB32(),
                    );
                    if (!mounted) return;
                    context.read<NoteProvider>().addFolder(folder);
                  } else {
                    widget.folder!.title = title;
                    widget.folder!.colorValue = _selectedColor.toARGB32();
                    await widget.folder!.save();

                    if (!mounted) return;
                    context.read<NoteProvider>().notifyListeners();
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: Text(
                  widget.folder == null ? 'Создать' : 'Сохранить изменения',
                  style: TextStyle(color: Colors.black, fontFamily: 'Oswald'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
