import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart'
    show listEquals, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inkflow/hive_models/save_note.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/note_provider.dart';
import 'package:inkflow/services/attachment_names.dart';
import 'package:inkflow/services/debouncer.dart';
import 'package:inkflow/services/note_content.dart';
import 'package:inkflow/services/note_sorting.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';
import 'package:inkflow/widgets/audio_player_widget.dart';
import 'package:inkflow/widgets/note_format_toolbar.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

enum OptionAction { save, saveAndExit, cancel }

enum AutoSaveStatus { idle, unsaved, saving, saved, error }

class CreateNoteScreen extends StatefulWidget {
  final SaveNote? note;
  final int? folderId;

  const CreateNoteScreen({super.key, this.note, this.folderId});

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen>
    with WidgetsBindingObserver {
  final TextEditingController _titleController = TextEditingController();
  late final QuillController _contentController;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

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
  AutoSaveStatus _saveStatus = AutoSaveStatus.idle;
  DateTime? _lastSavedTime;
  late DateTime _createdAt;
  String _lastSavedContent = '';
  late final Debouncer _autoSaveDebouncer = Debouncer(_autoSaveDelay);
  Future<void> _saveChain = Future.value();
  StreamSubscription<dynamic>? _contentChangesSubscription;

  static const Duration _autoSaveDelay = Duration(milliseconds: 600);

  bool _defaultsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _note = widget.note;
    _folderId = widget.folderId ?? widget.note?.folderId;
    _defaultNoteTitle = _formatDefaultTitle(DateTime.now());

    final initialDocument = NoteContent.parse(_note?.content);
    _contentController = QuillController(
      document: initialDocument,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _lastSavedContent = NoteContent.encode(initialDocument);

    if (_note != null) {
      _createdAt = _note!.createdAt ?? DateTime.now();
      _lastSavedTime = _note!.updatedAt ?? _note!.createdAt;
      _saveStatus = AutoSaveStatus.saved;
      _titleController.text = _note!.title;
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
      final defaultAudioTitle = AppLocalizations.translate('note.audioNote');
      _audioTitles =
          _note!.audioTitles?.toList() ??
          List.filled(_note!.audioNotes?.length ?? 0, defaultAudioTitle);
      _attachments = _note!.attachments?.toList() ?? [];
    } else {
      _createdAt = DateTime.now();
      _lastSavedTime = null;
      _saveStatus = AutoSaveStatus.idle;
      _titleController.text = _defaultNoteTitle;
    }

    _titleController.addListener(_onTextChanged);
    _contentChangesSubscription = _contentController.document.changes.listen(
      (_) => _onTextChanged(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshHasChanges();
    });
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _autoSaveDebouncer.cancel();
      unawaited(_saveNote(exit: false, notify: false, skipEmpty: true));
    }
  }

  String _formatDefaultTitle(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveDebouncer.dispose();
    _titleController.removeListener(_onTextChanged);
    _contentChangesSubscription?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _record.dispose();
    super.dispose();
  }

  // ============================ Отслеживание изменений ============================

  String get _serializedContent =>
      NoteContent.encode(_contentController.document);

  bool get _hasSomethingToSave {
    if (_note != null) return true;

    final title = _titleController.text;
    final hasUserTitle = title.trim().isNotEmpty && title != _defaultNoteTitle;

    return hasUserTitle ||
        _contentController.document.toPlainText().trim().isNotEmpty ||
        _selectedImage != null ||
        _audioPaths.isNotEmpty ||
        _attachments.isNotEmpty;
  }

  bool _computeHasChanges() {
    final note = _note;
    final contentChanged = _serializedContent != _lastSavedContent;

    if (note == null) {
      return _titleController.text != _defaultNoteTitle ||
          contentChanged ||
          _selectedImage != null ||
          _folderId != widget.folderId ||
          _hasCustomBackground ||
          _hasCustomTextColor ||
          _audioPaths.isNotEmpty ||
          _attachments.isNotEmpty;
    }

    final defaultAudioTitle = AppLocalizations.translate('note.audioNote');
    final noteAudioTitles =
        note.audioTitles ??
        List.filled(note.audioNotes?.length ?? 0, defaultAudioTitle);

    return _titleController.text != note.title ||
        contentChanged ||
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
      setState(() {
        _hasChanges = changed;
        if (!changed && _saveStatus != AutoSaveStatus.saving) {
          _saveStatus = (_note != null || _lastSavedTime != null)
              ? AutoSaveStatus.saved
              : AutoSaveStatus.idle;
        }
      });
    }
  }

  void _notifyChanged() {
    _refreshHasChanges();
    if (_hasChanges) {
      if (_saveStatus != AutoSaveStatus.saving && mounted) {
        setState(() => _saveStatus = AutoSaveStatus.unsaved);
      }
      _scheduleAutoSave();
    }
  }

  void _onTextChanged() {
    _notifyChanged();
  }

  void _scheduleAutoSave() {
    _autoSaveDebouncer.schedule(() {
      unawaited(_saveNote(exit: false, notify: false, skipEmpty: true));
    });
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(l10n.t('note.unsavedTitle'), style: const TextStyle()),
          content: Text(
            l10n.t('note.unsavedQuestion'),
            style: const TextStyle(),
          ),
          actions: [
            _dialogActionButton(
              label: l10n.t('common.cancel'),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurface,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            _dialogActionButton(
              label: l10n.t('common.save'),
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Widget _dialogActionButton({
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
    Color foregroundColor = Colors.white,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 18)),
    );
  }

  Future<void> _handleExit() async {
    _autoSaveDebouncer.cancel();

    if (_hasChanges && _hasSomethingToSave) {
      final saved = await _saveNote(exit: false, notify: false);
      if (!saved && mounted) {
        final shouldExit = await _showUnsavedChangesDialog();
        if (shouldExit && mounted) {
          Navigator.pop(context);
        }
        return;
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ============================ Сохранение ============================

  Future<bool> _saveNote({
    required bool exit,
    bool notify = true,
    bool skipEmpty = false,
  }) {
    _autoSaveDebouncer.cancel();

    final completer = Completer<bool>();
    _saveChain = _saveChain.then((_) async {
      try {
        final result = await _performSave(
          exit: exit,
          notify: notify,
          skipEmpty: skipEmpty,
        );
        completer.complete(result);
      } catch (e, stack) {
        completer.completeError(e, stack);
      }
    });

    return completer.future;
  }

  Future<bool> _performSave({
    required bool exit,
    required bool notify,
    required bool skipEmpty,
  }) async {
    final title = _titleController.text;
    final content = _serializedContent;
    final l10n = context.l10n;

    if (!_hasSomethingToSave) {
      if (skipEmpty) return false;
      if (notify) {
        _showSnackBar(l10n.t('note.emptyCannotSave'));
      }
      return false;
    }

    if (mounted) {
      setState(() {
        _saveStatus = AutoSaveStatus.saving;
      });
    }

    try {
      final noteProvider = context.read<NoteProvider>();
      final note = _note;

      if (note == null) {
        final now = DateTime.now();
        final newNote = SaveNote(
          title: title,
          content: content,
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
          createdAt: _createdAt,
          updatedAt: now,
        );
        await noteProvider.addNote(newNote);
        _note = newNote;
      } else {
        note
          ..title = title
          ..content = content
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
          ..hasCustomTextColor = _hasCustomTextColor
          ..updatedAt = DateTime.now();
        await noteProvider.saveNoteChanges(note);
      }

      if (!mounted) return true;

      _lastSavedContent = content;
      _lastSavedTime = _note?.updatedAt ?? DateTime.now();
      final stillHasChanges = _computeHasChanges();

      setState(() {
        _hasChanges = stillHasChanges;
        _saveStatus = stillHasChanges
            ? AutoSaveStatus.unsaved
            : AutoSaveStatus.saved;
      });

      if (stillHasChanges) {
        _scheduleAutoSave();
      }

      if (exit) {
        Navigator.pop(context);
      } else if (notify) {
        _showSnackBar(l10n.t('note.saved'));
      }

      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _saveStatus = AutoSaveStatus.error);
        if (notify) {
          _showSnackBar(l10n.t('note.saveFailed', {'error': e}));
        }
      }
      return false;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message, style: const TextStyle())));
  }

  // ============================ Изображение ============================

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      _notifyChanged();
    }
  }

  // ============================ Аудио ============================

  Future<String> _getAudioFilePath() async {
    final dir = await getApplicationSupportDirectory();
    final audioDir = Directory(p.join(dir.path, 'audio'));
    await audioDir.create(recursive: true);

    final isDesktop =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final extension = isDesktop ? 'wav' : 'm4a';
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return p.join(audioDir.path, 'note_audio_$timestamp.$extension');
  }

  Future<void> _startRecording() async {
    try {
      if (!await _record.hasPermission()) {
        _showSnackBar(AppLocalizations.translate('note.micPermission'));
        return;
      }

      final isDesktop =
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS;
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
      _showSnackBar(context.l10n.t('note.recordStartFailed', {'error': e}));
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
          _audioTitles.add(AppLocalizations.translate('note.audioNote'));
        }
      });
      _notifyChanged();
    } catch (e) {
      if (mounted) {
        setState(() => _isRecording = false);
      }
      _showSnackBar(context.l10n.t('note.recordStopFailed', {'error': e}));
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
    _notifyChanged();

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _updateAudioTitle(int index, String newTitle) {
    setState(() {
      if (_audioTitles.length <= index) {
        _audioTitles.addAll(
          List.filled(
            index - _audioTitles.length + 1,
            AppLocalizations.translate('note.audioNote'),
          ),
        );
      }
      _audioTitles[index] = newTitle;
    });
    _notifyChanged();
  }

  Widget _buildAudioWidget(String path, int index) {
    final themeProvider = context.watch<ThemeProvider>();

    return AudioPlayerWidget(
      filePath: path,
      audioTitle: _audioTitles.length > index
          ? _audioTitles[index]
          : AppLocalizations.translate('note.audioNote'),
      onTitleChanged: (newTitle) => _updateAudioTitle(index, newTitle),
      onDelete: () => _removeAudioPath(path, index),
      themeProvider: themeProvider,
    );
  }

  // ============================ Вложения ============================

  Future<void> _pickAttachments() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: context.l10n.t('note.addFilesTitle'),
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
      _notifyChanged();
    } catch (e) {
      _showSnackBar(context.l10n.t('note.addFilesFailed', {'error': e}));
    }
  }

  Future<void> _openAttachment(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      _showSnackBar(
        AppLocalizations.translate('note.openFileFailed', {
          'error': result.message,
        }),
      );
    }
  }

  Future<void> _removeAttachment(int index) async {
    final path = _attachments[index];
    setState(() => _attachments.removeAt(index));
    _notifyChanged();

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Widget _buildAttachmentWidget(String path, int index) {
    final extension = attachmentExtensionLabel(path);
    final displayName = attachmentDisplayName(path);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(FluentIcons.document_24_regular),
        title: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        subtitle: Text(
          extension.isEmpty ? context.l10n.t('note.file') : extension,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: context.l10n.t('common.open'),
              onPressed: () => _openAttachment(path),
              icon: const Icon(FluentIcons.open_24_regular),
            ),
            IconButton(
              tooltip: context.l10n.t('common.delete'),
              onPressed: () => _removeAttachment(index),
              icon: const Icon(FluentIcons.delete_24_regular),
            ),
          ],
        ),
      ),
    );
  }

  // ============================ Опции ============================

  Future<void> _showOptionsDialog() async {
    final l10n = context.l10n;
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
          title: Text(l10n.t('note.options'), style: const TextStyle()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: const Icon(FluentIcons.copy_24_regular),
                  title: Text(l10n.t('note.copyText')),
                  subtitle: Text(l10n.t('note.copyTextSubtitle')),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _copyNoteText();
                  },
                ),
                const SizedBox(height: 5),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: const Icon(FluentIcons.save_24_regular),
                  title: Text(l10n.t('note.exportTxt')),
                  subtitle: Text(l10n.t('note.exportTxtSubtitle')),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _exportNoteAsText();
                  },
                ),
                const SizedBox(height: 5),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: const Icon(FluentIcons.folder_24_regular),
                  title: Text(l10n.t('folder.moveTo')),
                  subtitle: Text(l10n.t('note.moveToFolderSubtitle')),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showMoveToFolderSheet();
                  },
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: _dialogActionButton(
                label: l10n.t('common.cancel'),
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
    final content = NoteContent.plainText(_serializedContent);
    return [title, content].where((part) => part.isNotEmpty).join('\n\n');
  }

  Future<void> _copyNoteText() async {
    final text = _noteAsPlainText();
    if (text.trim().isEmpty) {
      _showSnackBar(context.l10n.t('note.noTextInNote'));
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showSnackBar(context.l10n.t('note.textCopied'));
  }

  Future<void> _exportNoteAsText() async {
    try {
      final text = _noteAsPlainText();
      final rawTitle = _titleController.text.trim();
      final fileName = rawTitle.isEmpty ? _defaultNoteTitle : rawTitle;
      final safeFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      final uri = await FilePicker.saveFile(
        dialogTitle: context.l10n.t('note.exportDialogTitle'),
        fileName: '$safeFileName.txt',
        bytes: Uint8List.fromList(utf8.encode(text)),
        mimeType: 'text/plain',
      );

      if (!mounted) return;
      if (uri != null) {
        _showSnackBar(context.l10n.t('note.exported'));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(context.l10n.t('note.exportFailed', {'error': e}));
    }
  }

  Future<void> _showMoveToFolderSheet() async {
    final folders = context.read<NoteProvider>().folders;
    final l10n = context.l10n;

    final selected = await showModalBottomSheet<Object?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (dialogContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                FluentIcons.desktop_24_regular,
                color: Colors.teal,
              ),
              title: Text(
                l10n.t('folder.none'),
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => Navigator.pop(dialogContext, 'no_folder'),
            ),
            const Divider(indent: 16, endIndent: 16),
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24.0,
                  horizontal: 16.0,
                ),
                child: Center(
                  child: Text(
                    l10n.t('folder.noFolders'),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(folder.colorValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(folder.title),
                      onTap: () => Navigator.pop(dialogContext, folder.key),
                    );
                  },
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
    _notifyChanged();
    _showSnackBar(
      _folderId == null
          ? context.l10n.t('folder.savedWithout')
          : context.l10n.t('folder.selected'),
    );
  }

  // ============================ Диалоги оформления ============================

  void _showRestoreDialog(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(context);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            l10n.t('note.restoreBackgroundQuestion'),
            style: const TextStyle(),
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
              child: Text(
                l10n.t('common.cancel'),
                style: const TextStyle(fontSize: 18),
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
                _notifyChanged();
                Navigator.pop(dialogContext);
              },
              child: Text(
                l10n.t('common.restore'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBackgroundColorDialog(BuildContext context) {
    Color tempColor = _backgroundColor ?? _defaultBackgroundColor;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(l10n.t('common.selectColor'), style: const TextStyle()),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (color) => tempColor = color,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            _dialogActionButton(
              label: l10n.t('common.cancel'),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurface,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            _dialogActionButton(
              label: l10n.t('common.choose'),
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _backgroundColor = tempColor;
                  _hasCustomBackground = true;
                });
                _notifyChanged();
                Navigator.pop(dialogContext);
              },
            ),
          ],
        );
      },
    );
  }

  void _showTextColorDialog(BuildContext context) {
    Color tempColor = _textColor ?? _defaultTextColor;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(l10n.t('common.selectColor'), style: const TextStyle()),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (color) => tempColor = color,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            _dialogActionButton(
              label: l10n.t('common.cancel'),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurface,
              onPressed: () => Navigator.pop(dialogContext),
            ),
            _dialogActionButton(
              label: l10n.t('common.choose'),
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _textColor = tempColor;
                  _hasCustomTextColor = true;
                });
                _notifyChanged();
                Navigator.pop(dialogContext);
              },
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
    final accentColor = theme.colorScheme.primary;
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
      selectionColor: accentColor.withValues(alpha: 0.3),
      selectionHandleColor: accentColor,
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
          centerTitle: true,
          title: _buildAppBarHeader(context, theme),
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
                      cursorColor: accentColor,
                      style: TextStyle(
                        fontSize: 25,
                        fontFamilyFallback: const ['Apple'],
                        color: effectiveTextColor,
                      ),
                      decoration: InputDecoration(
                        hint: Text(
                          context.l10n.t('note.titleHint'),
                          style: TextStyle(
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
                      textSelectionTheme: textSelectionTheme.copyWith(
                        cursorColor: accentColor,
                      ),
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontFamily: themeProvider.fontFamily,
                        fontSize: 18,
                        fontFamilyFallback: const ['Apple'],
                        color: effectiveTextColor,
                      ),
                      child: QuillEditor(
                        controller: _contentController,
                        focusNode: _editorFocusNode,
                        scrollController: _editorScrollController,
                        config: QuillEditorConfig(
                          placeholder: context.l10n.t('note.contentHint'),
                          padding: const EdgeInsets.all(18),
                          scrollable: false,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
        // floatingActionButton: FloatingActionButton(
        //   onPressed: () => _saveNote(exit: true),
        //   backgroundColor: primaryColor,
        //   shape: const CircleBorder(),
        //   child: Icon(FluentIcons.save_24_regular, color: onPrimaryColor),
        // ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NoteFormatToolbar(
              controller: _contentController,
              focusNode: _editorFocusNode,
              primaryColor: accentColor,
            ),
            BottomAppBar(
              color: primaryColor,
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: context.l10n.t('note.bgColorTooltip'),
                    icon: Icon(
                      FluentIcons.color_24_regular,
                      color: onPrimaryColor,
                    ),
                    onPressed: () => _showBackgroundColorDialog(context),
                  ),
                  IconButton(
                    tooltip: context.l10n.t('note.textColorTooltip'),
                    icon: Icon(
                      FluentIcons.text_16_regular,
                      color: onPrimaryColor,
                    ),
                    onPressed: () => _showTextColorDialog(context),
                  ),
                  IconButton(
                    tooltip: context.l10n.t('note.bgImageTooltip'),
                    icon: Icon(
                      FluentIcons.image_24_regular,
                      color: onPrimaryColor,
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                  IconButton(
                    tooltip: context.l10n.t('note.resetBgTooltip'),
                    icon: Icon(
                      FluentIcons.arrow_reset_24_regular,
                      color: onPrimaryColor,
                    ),
                    onPressed: () => _showRestoreDialog(context),
                  ),
                  IconButton(
                    tooltip: _isRecording
                        ? context.l10n.t('note.stopRecording')
                        : context.l10n.t('note.recordAudio'),
                    icon: Icon(
                      _isRecording
                          ? FluentIcons.stop_24_regular
                          : FluentIcons.mic_24_regular,
                      color: _isRecording ? Colors.red : onPrimaryColor,
                    ),
                    onPressed: _toggleRecording,
                  ),
                  IconButton(
                    tooltip: context.l10n.t('note.addFilesTooltip'),
                    icon: Icon(
                      FluentIcons.attach_24_regular,
                      color: onPrimaryColor,
                    ),
                    onPressed: _pickAttachments,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarHeader(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    final secondaryColor = theme.colorScheme.onSurfaceVariant;
    final themeProvider = context.watch<ThemeProvider>();

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildStatusWidget(context, theme, l10n, themeProvider.fontFamily),
          const SizedBox(height: 2),
          Text(
            l10n.t('note.createdAt', {
              'date': formatNoteDateTime(context, _createdAt),
            }),
            style: TextStyle(
              fontFamily: themeProvider.fontFamily,
              fontSize: 11,
              color: secondaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusWidget(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    String fontFamily,
  ) {
    switch (_saveStatus) {
      case AutoSaveStatus.saving:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.t('note.statusSaving'),
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        );
      case AutoSaveStatus.saved:
        final timeStr = _lastSavedTime != null
            ? formatNoteTime(context, _lastSavedTime!)
            : '';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FluentIcons.checkmark_12_regular,
              size: 13,
              color: Colors.green,
            ),
            const SizedBox(width: 4),
            Text(
              l10n.t('note.statusSavedAt', {'time': timeStr}),
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        );
      case AutoSaveStatus.unsaved:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              l10n.t('note.statusUnsaved'),
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        );
      case AutoSaveStatus.error:
        return InkWell(
          onTap: () => _saveNote(exit: false),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  FluentIcons.warning_16_regular,
                  size: 14,
                  color: Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.t('note.statusError'),
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: l10n.t('note.retrySave'),
                  child: const Icon(
                    FluentIcons.arrow_clockwise_12_regular,
                    size: 12,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        );
      case AutoSaveStatus.idle:
        return Text(
          l10n.t('note.newNote'),
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
    }
  }
}
