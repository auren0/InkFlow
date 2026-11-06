import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:note_app/hive_models/save_note.dart';
import 'package:note_app/providers/note_provider.dart';
import 'package:note_app/shared_preferences/theme_provider.dart';
import 'package:note_app/widgets/audio_player_widget.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

enum OptionAction { save, saveAndExit, cancel }

class CreateNoteScreen extends StatefulWidget {
  final SaveNote? note;
  final int? folderId;

  const CreateNoteScreen({super.key, this.note, this.folderId});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  late final Color _defaultBackgroundColor;
  late final Color _defaultTextColor;
  late final String _defaultNoteTitle;

  SaveNote? _note;
  int? _folderId;

  Color? _backgroundColor;
  Color? _textColor;
  bool _hasCustomBackground = false;
  bool _hasCustomTextColor = false;

  File? _selectedImage;

  bool _isRecording = false;
  final AudioRecorder _record = AudioRecorder();

  List<String> _audioPaths = [];
  List<String> _audioTitles = [];
  List<String> _attachments = [];

  bool _hasChanges = false;
  bool _isSaving = false;

  bool _defaultsInitialized = false;

  @override
  void initState() {
    super.initState();

    _note = widget.note;
    _folderId = widget.folderId ?? widget.note?.folderId;
    _defaultNoteTitle = _formatDefaultTitle(DateTime.now());

    if (_note != null) {
      _titleController.text = _note!.title;
      _contentController.text = _note!.content;
      if (_note!.backgroundImagePath != null &&
          _note!.backgroundImagePath!.isNotEmpty) {
        _selectedImage = File(_note!.backgroundImagePath!);
      }

      _hasCustomBackground =
          _note!.usesCustomBackground && _note!.backgroundColorValue != null;
      _backgroundColor = _hasCustomBackground
          ? Color(_note!.backgroundColorValue!)
          : null;

      _hasCustomTextColor =
          _note!.usesCustomTextColor && _note!.textColorValue != null;
      _textColor = _hasCustomTextColor ? Color(_note!.textColorValue!) : null;

      _audioPaths = _note!.audioNotes?.toList() ?? [];
      _audioTitles =
          _note!.audioTitles?.toList() ??
          List.filled(_note!.audioNotes?.length ?? 0, 'Аудио заметка');
      _attachments = _note!.attachments?.toList() ?? [];
    } else {
      _titleController.text = _defaultNoteTitle;
    }

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_defaultsInitialized) return;
    _defaultsInitialized = true;

    final theme = Theme.of(context);
    _defaultBackgroundColor = theme.scaffoldBackgroundColor;
    _defaultTextColor = theme.colorScheme.onSurface;
  }

  String _formatDefaultTitle(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    _record.dispose();
    super.dispose();
  }

  // ============================ Отслеживание изменений ============================

  bool _computeHasChanges() {
    final note = _note;

    if (note == null) {
      return _titleController.text != _defaultNoteTitle ||
          _contentController.text.isNotEmpty ||
          _selectedImage != null ||
          _folderId != widget.folderId ||
          _hasCustomBackground ||
          _hasCustomTextColor ||
          _audioPaths.isNotEmpty ||
          _attachments.isNotEmpty;
    }

    final noteAudioTitles =
        note.audioTitles ??
        List.filled(note.audioNotes?.length ?? 0, 'Аудио заметка');

    return _titleController.text != note.title ||
        _contentController.text != note.content ||
        _folderId != note.folderId ||
        _selectedImage?.path != note.backgroundImagePath ||
        _hasCustomBackground != note.usesCustomBackground ||
        (_hasCustomBackground &&
            _backgroundColor?.toARGB32() != note.backgroundColorValue) ||
        _hasCustomTextColor != note.usesCustomTextColor ||
        (_hasCustomTextColor &&
            _textColor?.toARGB32() != note.textColorValue) ||
        !listEquals(_audioPaths, note.audioNotes ?? const []) ||
        !listEquals(_audioTitles, noteAudioTitles) ||
        !listEquals(_attachments, note.attachments ?? const []);
  }

  void _refreshHasChanges() {
    final changed = _computeHasChanges();
    if (changed != _hasChanges && mounted) {
      setState(() => _hasChanges = changed);
    }
  }

  void _onTextChanged() => _refreshHasChanges();

  // ============================ Выход и сохранение ============================

  Future<OptionAction> _showUnsavedChangesDialog() async {
    final theme = Theme.of(context);

    final result = await showDialog<OptionAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Вы изменили заметку!',
            style: TextStyle(fontFamily: 'Oswald'),
          ),
          content: Text(
            'Хотите ли вы сохранить текущие изменения?',
            style: TextStyle(
              fontFamily: 'Oswald',
              color: theme.colorScheme.onSurface,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _dialogActionButton(
                          label: 'Сохранить',
                          backgroundColor: const Color(0xFF16A34A),
                          onPressed: () =>
                              Navigator.pop(dialogContext, OptionAction.save),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _dialogActionButton(
                          label: 'Сохранить и выйти',
                          backgroundColor: const Color(0xFF2563EB),
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            OptionAction.saveAndExit,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _dialogActionButton(
                      label: 'Отмена',
                      backgroundColor: const Color(0xFF64748B),
                      onPressed: () =>
                          Navigator.pop(dialogContext, OptionAction.cancel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    return result ?? OptionAction.cancel;
  }

  Widget _dialogActionButton({
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontFamily: 'Oswald', fontSize: 16),
          ),
        ),
      ),
    );
  }

  Future<void> _handleExit() async {
    if (!_hasChanges) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final action = await _showUnsavedChangesDialog();
    if (!mounted) return;

    switch (action) {
      case OptionAction.save:
        await _saveNote(exit: false);
        break;
      case OptionAction.saveAndExit:
        await _saveNote(exit: true);
        break;
      case OptionAction.cancel:
        break;
    }
  }

  Future<void> _saveNote({bool exit = true}) async {
    if (_isSaving) return;

    final title = _titleController.text;
    final hasUserTitle = title.trim().isNotEmpty && title != _defaultNoteTitle;
    final hasSomething =
        hasUserTitle ||
        _contentController.text.isNotEmpty ||
        _selectedImage != null ||
        _audioPaths.isNotEmpty ||
        _attachments.isNotEmpty;

    if (!hasSomething) {
      _showSnackBar('Пустую заметку сохранить нельзя');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final noteProvider = context.read<NoteProvider>();
      final note = _note;

      if (note == null) {
        final newNote = SaveNote(
          title: title,
          content: _contentController.text,
          folderId: _folderId,
          backgroundImagePath: _selectedImage?.path,
          textColorValue: _hasCustomTextColor ? _textColor?.toARGB32() : null,
          backgroundColorValue: _hasCustomBackground
              ? _backgroundColor?.toARGB32()
              : null,
          audioNotes: _audioPaths.toList(),
          audioTitles: _audioTitles.toList(),
          attachments: _attachments.toList(),
          hasCustomBackground: _hasCustomBackground,
          hasCustomTextColor: _hasCustomTextColor,
        );
        await noteProvider.addNote(newNote);
        _note = newNote;
      } else {
        note
          ..title = title
          ..content = _contentController.text
          ..folderId = _folderId
          ..backgroundImagePath = _selectedImage?.path
          ..textColorValue = _hasCustomTextColor ? _textColor?.toARGB32() : null
          ..backgroundColorValue = _hasCustomBackground
              ? _backgroundColor?.toARGB32()
              : null
          ..audioNotes = _audioPaths.toList()
          ..audioTitles = _audioTitles.toList()
          ..attachments = _attachments.toList()
          ..hasCustomBackground = _hasCustomBackground
          ..hasCustomTextColor = _hasCustomTextColor;
        await noteProvider.saveNoteChanges(note);
      }

      if (!mounted) return;

      setState(() => _hasChanges = false);

      if (exit) {
        Navigator.pop(context);
      } else {
        _showSnackBar('Заметка сохранена');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Не удалось сохранить заметку: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Oswald')),
      ),
    );
  }

  // ============================ Изображение ============================

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      _refreshHasChanges();
    }
  }

  // ============================ Аудио ============================

  Future<String> _getAudioFilePath() async {
    final dir = await getApplicationSupportDirectory();
    final audioDir = Directory(p.join(dir.path, 'audio'));
    await audioDir.create(recursive: true);

    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final extension = isDesktop ? 'wav' : 'm4a';
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return p.join(audioDir.path, 'note_audio_$timestamp.$extension');
  }

  Future<void> _startRecording() async {
    try {
      if (!await _record.hasPermission()) {
        _showSnackBar('Нет разрешения на использование микрофона');
        return;
      }

      final isDesktop =
          Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      final path = await _getAudioFilePath();

      await _record.start(
        RecordConfig(
          encoder: isDesktop ? AudioEncoder.wav : AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() => _isRecording = true);
    } catch (e) {
      _showSnackBar('Не удалось начать запись: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _record.stop();
      if (!mounted) return;

      setState(() {
        _isRecording = false;
        if (path != null) {
          _audioPaths.add(path);
          _audioTitles.add('Аудио заметка');
        }
      });
      _refreshHasChanges();
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
      }
      _showSnackBar('Не удалось остановить запись: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _removeAudioPath(String path, int index) async {
    setState(() {
      _audioPaths.removeAt(index);
      if (_audioTitles.length > index) {
        _audioTitles.removeAt(index);
      }
    });
    _refreshHasChanges();

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _updateAudioTitle(int index, String newTitle) {
    setState(() {
      if (_audioTitles.length <= index) {
        _audioTitles.addAll(
          List.filled(index - _audioTitles.length + 1, 'Аудио заметка'),
        );
      }
      _audioTitles[index] = newTitle;
    });
    _refreshHasChanges();
  }

  Widget _buildAudioWidget(String path, int index) {
    final themeProvider = context.watch<ThemeProvider>();

    return AudioPlayerWidget(
      filePath: path,
      audioTitle: _audioTitles.length > index
          ? _audioTitles[index]
          : 'Аудио заметка',
      onTitleChanged: (newTitle) => _updateAudioTitle(index, newTitle),
      onDelete: () => _removeAudioPath(path, index),
      themeProvider: themeProvider,
    );
  }

  // ============================ Вложения ============================

  Future<void> _pickAttachments() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Добавить файлы к заметке',
      );

      if (files.isEmpty) return;

      final dir = await getApplicationSupportDirectory();
      final attachmentsDir = Directory(p.join(dir.path, 'attachments'));
      await attachmentsDir.create(recursive: true);

      final addedPaths = <String>[];
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final fileName = p.basename(file.name);
        final destination = p.join(
          attachmentsDir.path,
          '${DateTime.now().microsecondsSinceEpoch}_${i}_$fileName',
        );

        final sourcePath = file.path;
        if (sourcePath != null) {
          await File(sourcePath).copy(destination);
        } else {
          final bytes = await file.readAsBytes();
          await File(destination).writeAsBytes(bytes, flush: true);
        }

        addedPaths.add(destination);
      }

      if (!mounted) return;
      setState(() => _attachments.addAll(addedPaths));
      _refreshHasChanges();
    } catch (e) {
      _showSnackBar('Не удалось добавить файлы: $e');
    }
  }

  Future<void> _openAttachment(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      _showSnackBar('Не удалось открыть файл: ${result.message}');
    }
  }

  Future<void> _removeAttachment(int index) async {
    final path = _attachments[index];
    setState(() => _attachments.removeAt(index));
    _refreshHasChanges();

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Widget _buildAttachmentWidget(String path, int index) {
    final extension = p.extension(path).replaceFirst('.', '').toUpperCase();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(FluentIcons.document_24_regular),
        title: Text(
          p.basename(path),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Oswald', fontSize: 16),
        ),
        subtitle: Text(
          extension.isEmpty ? 'Файл' : extension,
          style: const TextStyle(fontFamily: 'Oswald', fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Открыть',
              onPressed: () => _openAttachment(path),
              icon: const Icon(FluentIcons.open_24_regular),
            ),
            IconButton(
              tooltip: 'Удалить',
              onPressed: () => _removeAttachment(index),
              icon: const Icon(FluentIcons.delete_24_regular),
            ),
          ],
        ),
      ),
    );
  }

  // ============================ Options dialog ============================

  Future<void> _showOptionsDialog() async {
    final action = await showDialog<OptionAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Дополнительные опции',
            style: TextStyle(fontFamily: 'Oswald'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // const SizedBox(height: 12),
                // const Divider(),
                ListTile(
                  // contentPadding: EdgeInsets.zero,
                  leading: const Icon(FluentIcons.copy_24_regular),
                  title: const Text(
                    'Копировать текст',
                    style: TextStyle(fontFamily: 'Oswald'),
                  ),
                  subtitle: const Text(
                    'Название и содержимое заметки',
                    style: TextStyle(fontFamily: 'Oswald'),
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _copyNoteText();
                  },
                ),
                ListTile(
                  // contentPadding: EdgeInsets.zero,
                  leading: const Icon(FluentIcons.save_24_regular),
                  title: const Text(
                    'Экспортировать в .txt',
                    style: TextStyle(fontFamily: 'Oswald'),
                  ),
                  subtitle: const Text(
                    'Сохранить заметку как текстовый файл',
                    style: TextStyle(fontFamily: 'Oswald'),
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _exportNoteAsText();
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  // contentPadding: EdgeInsets.zero,
                  leading: const Icon(FluentIcons.folder_24_regular),
                  title: const Text(
                    'Переместить в папку',
                    style: TextStyle(fontFamily: 'Oswald'),
                  ),
                  subtitle: const Text(
                    'Выбрать папку для заметки',
                    style: TextStyle(fontFamily: 'Oswald'),
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showMoveToFolderDialog();
                  },
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: _dialogActionButton(
                label: 'Отмена',
                backgroundColor: const Color(0xFF64748B),
                onPressed: () =>
                    Navigator.pop(dialogContext, OptionAction.cancel),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    switch (action) {
      case OptionAction.save:
        await _saveNote(exit: false);
        break;
      case OptionAction.saveAndExit:
        await _saveNote(exit: true);
        break;
      case OptionAction.cancel:
      case null:
        break;
    }
  }

  String _noteAsPlainText() {
    final title = _titleController.text;
    final content = _contentController.text;
    return [title, content].where((part) => part.isNotEmpty).join('\n\n');
  }

  Future<void> _copyNoteText() async {
    final text = _noteAsPlainText();
    if (text.trim().isEmpty) {
      _showSnackBar('В заметке нет текста');
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Текст скопирован');
  }

  Future<void> _exportNoteAsText() async {
    try {
      final text = _noteAsPlainText();
      final rawTitle = _titleController.text.trim();
      final fileName = rawTitle.isEmpty ? _defaultNoteTitle : rawTitle;
      final safeFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Экспортировать заметку',
        fileName: '$safeFileName.txt',
        bytes: Uint8List.fromList(utf8.encode(text)),
        mimeType: 'text/plain',
      );

      if (uri != null) {
        _showSnackBar('Заметка экспортирована');
      }
    } catch (e) {
      _showSnackBar('Не удалось экспортировать заметку: $e');
    }
  }

  Future<void> _showMoveToFolderDialog() async {
    final folders = context.read<NoteProvider>().folders;

    if (folders.isEmpty) {
      _showSnackBar('Сначала создайте папку');
      return;
    }

    final selected = await showDialog<Object?>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text(
            'Переместить в папку',
            style: TextStyle(fontFamily: 'Oswald'),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'no_folder'),
              child: const Text(
                'Без папки',
                style: TextStyle(fontFamily: 'Oswald'),
              ),
            ),
            ...folders.map(
              (folder) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, folder.key),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Color(folder.colorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        folder.title,
                        style: const TextStyle(fontFamily: 'Oswald'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || selected == null) return;

    setState(() {
      _folderId = selected is int ? selected : null;
    });
    _refreshHasChanges();
    _showSnackBar(
      _folderId == null
          ? 'Заметка будет сохранена без папки'
          : 'Папка выбрана. Сохраните заметку',
    );
  }

  // ============================ Диалоги оформления ============================

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(context);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Вы точно хотите вернуть задний фон по умолчанию?',
            style: TextStyle(fontFamily: 'Oswald'),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14.0,
                  horizontal: 20.0,
                ),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Отмена',
                style: TextStyle(fontFamily: 'Oswald', fontSize: 18),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14.0,
                  horizontal: 20.0,
                ),
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() => _selectedImage = null);
                _refreshHasChanges();
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Восстановить',
                style: TextStyle(fontFamily: 'Oswald', fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBackgroundColorDialog(BuildContext context) {
    Color tempColor = _backgroundColor ?? _defaultBackgroundColor;
    final themeProvider = context.read<ThemeProvider>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(context);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Выберите цвет для заднего фона',
            style: TextStyle(fontFamily: 'Oswald'),
          ),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14.0,
                  horizontal: 20.0,
                ),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Отмена',
                style: TextStyle(fontFamily: 'Oswald', fontSize: 18),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14.0,
                  horizontal: 20.0,
                ),
                backgroundColor: themeProvider.primaryColor,
                foregroundColor: themeProvider.onPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() {
                  _backgroundColor = tempColor;
                  _hasCustomBackground = true;
                });
                _refreshHasChanges();
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Выбрать',
                style: TextStyle(fontFamily: 'Oswald', fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTextColorDialog(BuildContext context) {
    Color tempColor = _textColor ?? _defaultTextColor;
    final themeProvider = context.read<ThemeProvider>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(context);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Выберите цвет для текста',
            style: TextStyle(fontFamily: 'Oswald'),
          ),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14.0,
                  horizontal: 20.0,
                ),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Отмена',
                style: TextStyle(fontFamily: 'Oswald', fontSize: 18),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14.0,
                  horizontal: 20.0,
                ),
                backgroundColor: themeProvider.primaryColor,
                foregroundColor: themeProvider.onPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() {
                  _textColor = tempColor;
                  _hasCustomTextColor = true;
                });
                _refreshHasChanges();
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Выбрать',
                style: TextStyle(fontFamily: 'Oswald', fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================ UI ============================

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final primaryColor = themeProvider.primaryColor;
    final onPrimaryColor = themeProvider.onPrimaryColor;
    final effectiveBackgroundColor = _hasCustomBackground
        ? (_backgroundColor ?? theme.scaffoldBackgroundColor)
        : theme.scaffoldBackgroundColor;
    final defaultTextColor =
        _hasCustomBackground &&
            effectiveBackgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : theme.colorScheme.onSurface;
    final effectiveTextColor = _hasCustomTextColor
        ? (_textColor ?? defaultTextColor)
        : defaultTextColor;
    final textSelectionTheme = TextSelectionThemeData(
      selectionColor: primaryColor.withValues(alpha: 0.3),
      selectionHandleColor: primaryColor,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleExit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _handleExit,
            icon: const Icon(FluentIcons.edit_arrow_back_24_regular),
          ),
          actions: [
            IconButton(
              onPressed: _showOptionsDialog,
              icon: const Icon(FluentIcons.options_24_regular),
            ),
          ],
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _selectedImage == null ? effectiveBackgroundColor : null,
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            SingleChildScrollView(
              child: Column(
                children: [
                  Theme(
                    data: theme.copyWith(
                      textSelectionTheme: textSelectionTheme,
                    ),
                    child: TextField(
                      controller: _titleController,
                      maxLines: null,
                      cursorColor: primaryColor,
                      style: TextStyle(
                        fontSize: 25,
                        fontFamily: 'Jura',
                        fontFamilyFallback: const ['Apple'],
                        color: effectiveTextColor,
                      ),
                      decoration: InputDecoration(
                        hint: Text(
                          'Введи название :>',
                          style: TextStyle(
                            fontFamily: 'Oswald',
                            fontSize: 25,
                            color: effectiveTextColor.withValues(alpha: 0.5),
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  if (_audioPaths.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: List.generate(
                          _audioPaths.length,
                          (index) =>
                              _buildAudioWidget(_audioPaths[index], index),
                        ),
                      ),
                    ),
                  if (_attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: List.generate(
                          _attachments.length,
                          (index) => _buildAttachmentWidget(
                            _attachments[index],
                            index,
                          ),
                        ),
                      ),
                    ),
                  Theme(
                    data: theme.copyWith(
                      textSelectionTheme: textSelectionTheme,
                    ),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      cursorColor: primaryColor,
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Jura',
                        fontFamilyFallback: const ['Apple'],
                        color: effectiveTextColor,
                      ),
                      decoration: InputDecoration(
                        hint: Text(
                          'Введи заметку ^_^',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Oswald',
                            color: effectiveTextColor.withValues(alpha: 0.5),
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _saveNote(exit: true),
          backgroundColor: primaryColor,
          shape: const CircleBorder(),
          child: Icon(FluentIcons.save_24_regular, color: onPrimaryColor),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          color: primaryColor,
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Цвет фона',
                icon: Icon(FluentIcons.color_24_regular, color: onPrimaryColor),
                onPressed: () => _showBackgroundColorDialog(context),
              ),
              IconButton(
                tooltip: 'Цвет текста',
                icon: Icon(FluentIcons.text_16_regular, color: onPrimaryColor),
                onPressed: () => _showTextColorDialog(context),
              ),
              IconButton(
                tooltip: 'Фоновое изображение',
                icon: Icon(FluentIcons.image_24_regular, color: onPrimaryColor),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
              IconButton(
                tooltip: 'Сбросить фон',
                icon: Icon(
                  FluentIcons.arrow_reset_24_regular,
                  color: onPrimaryColor,
                ),
                onPressed: () => _showRestoreDialog(context),
              ),
              IconButton(
                tooltip: _isRecording ? 'Остановить запись' : 'Записать аудио',
                icon: Icon(
                  _isRecording
                      ? FluentIcons.stop_24_regular
                      : FluentIcons.mic_24_regular,
                  color: _isRecording ? Colors.red : onPrimaryColor,
                ),
                onPressed: _toggleRecording,
              ),
              IconButton(
                tooltip: 'Добавить файлы',
                icon: Icon(
                  FluentIcons.attach_24_regular,
                  color: onPrimaryColor,
                ),
                onPressed: _pickAttachments,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
