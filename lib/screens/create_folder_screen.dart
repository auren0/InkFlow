import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:inkflow/hive_models/save_folder.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/note_provider.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';
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
        : context.read<ThemeProvider>().primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('folder.create'), style: TextStyle())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20.0),
                  foregroundColor: accentColor,
                  // backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: accentColor, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Color tempColor = _selectedColor;

                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => AlertDialog(
                      title: Text(
                        l10n.t('folder.colorDialog'),
                        style: TextStyle(),
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
                            side: BorderSide(color: accentColor, width: 2),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            l10n.t('common.cancel'),
                            style: TextStyle(color: accentColor, fontSize: 18),
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
                            backgroundColor: themeProvider.primaryColor,
                            foregroundColor: themeProvider.onPrimaryColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedColor = tempColor;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            l10n.t('common.choose'),
                            style: TextStyle(
                              fontSize: 18,
                              color: themeProvider.onPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  l10n.t('folder.tagColor'),
                  style: TextStyle(color: accentColor),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  selectionColor: accentColor.withValues(alpha: 0.3),
                  selectionHandleColor: accentColor,
                ),
              ),
              child: TextField(
                controller: _folderTitleController,
                cursorColor: accentColor,
                decoration: InputDecoration(
                  floatingLabelStyle: TextStyle(color: accentColor),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: accentColor, width: 2),
                    // borderRadius: BorderRadius.circular(10),
                  ),
                  focusColor: accentColor,
                  border: OutlineInputBorder(),
                  label: Text(l10n.t('folder.name'), style: TextStyle()),
                  hint: Text(l10n.t('folder.nameHint'), style: TextStyle()),
                ),
                style: TextStyle(fontFamilyFallback: ['Apple']),
              ),
            ),
            const SizedBox(height: 45),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(20.0),
                  backgroundColor: themeProvider.primaryColor,
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
                        content: Text(
                          l10n.t('folder.nameRequired'),
                          style: TextStyle(),
                        ),
                      ),
                    );
                    return;
                  }

                  final noteProvider = context.read<NoteProvider>();

                  if (widget.folder == null) {
                    final folder = SaveFolder(
                      title: title,
                      colorValue: _selectedColor.toARGB32(),
                    );
                    await noteProvider.addFolder(folder);
                  } else {
                    widget.folder!.title = title;
                    widget.folder!.colorValue = _selectedColor.toARGB32();
                    await noteProvider.saveFolderChanges(widget.folder!);
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: Text(
                  widget.folder == null
                      ? l10n.t('common.create')
                      : l10n.t('folder.saveChanges'),
                  style: TextStyle(color: themeProvider.onPrimaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
