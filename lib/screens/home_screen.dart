import 'dart:ui' show PointerDeviceKind;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:inkflow/hive_models/save_note.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/note_provider.dart';
import 'package:inkflow/screens/create_note_screen.dart';
import 'package:inkflow/services/note_content.dart';
import 'package:inkflow/services/note_sorting.dart';
import 'package:inkflow/shared_preferences/note_settings_provider.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';
import 'package:inkflow/widgets/date_group_header.dart';
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
    final noteSettings = context.watch<NoteSettingsProvider>();
    // final notes = noteProvider.notes;
    final notes = NoteSorting.newestFirst(
      noteProvider.notes.where((note) => note.folderId == null),
    );
    final l10n = context.l10n;

    return Scaffold(
      body: notes.isEmpty
          ? Center(child: Text(l10n.t('notes.empty'), style: TextStyle()))
          : noteSettings.groupByDate
          ? _buildGroupedNotes(context, notes, noteProvider)
          : _buildNoteGrid(context, notes, noteProvider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const CreateNoteScreen()),
          );
        },
        backgroundColor: themeProvider.primaryColor,
        icon: Icon(
          FluentIcons.add_24_regular,
          color: themeProvider.onPrimaryColor,
        ),
        label: Text(
          l10n.t('notes.create'),
          style: TextStyle(color: themeProvider.onPrimaryColor),
        ),
      ),
    );
  }

  Widget _buildNoteGrid(
    BuildContext context,
    List<SaveNote> notes,
    NoteProvider noteProvider,
  ) {
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
  }

  Widget _buildGroupedNotes(
    BuildContext context,
    List<SaveNote> notes,
    NoteProvider noteProvider,
  ) {
    final groups = NoteSorting.groupByLocalDate(notes);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 250,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1,
    );

    return CustomScrollView(
      slivers: [
        for (final group in groups) ...[
          SliverToBoxAdapter(child: DateGroupHeader(date: group.date)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate((context, index) {
                final note = group.notes[index];
                return NoteCard(note: note, noteProvider: noteProvider);
              }, childCount: group.notes.length),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: 88 + bottomInset)),
      ],
    );
  }
}

enum _NoteMenuAction { edit, archive, removeFromFolder, moveToFolder, delete }

class NoteCard extends StatefulWidget {
  final SaveNote note;
  final NoteProvider noteProvider;

  const NoteCard({super.key, required this.note, required this.noteProvider});

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  Color borderColor = Colors.white;
  PointerDeviceKind? _lastPointerKind;

  bool get _isDesktopPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  void _editNote() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => CreateNoteScreen(note: widget.note)),
    );
  }

  void _archiveNote() {
    widget.noteProvider.addToArchive(widget.note);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.t('notes.archived'),
          style: const TextStyle(),
        ),
      ),
    );
  }

  void _removeFromFolder() {
    widget.noteProvider.removeNoteFromFolder(widget.note);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.t('notes.movedToDesktop'),
          style: const TextStyle(),
        ),
      ),
    );
  }

  void _deleteNote() {
    widget.noteProvider.moveNoteToTrash(widget.note);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.t('notes.movedToTrash'),
          style: const TextStyle(),
        ),
      ),
    );
  }

  void _showFolderSelectionSheet() {
    final noteProvider = widget.noteProvider;
    final folders = noteProvider.folders;
    final l10n = context.l10n;
    final isInFolder = widget.note.folderId != null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Column(
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
          const SizedBox(height: 10),
          if (isInFolder) ...[
            ListTile(
              leading: const Icon(
                FluentIcons.desktop_24_regular,
                color: Colors.teal,
              ),
              title: Text(
                l10n.t('notes.moveToDesktop'),
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _removeFromFolder();
              },
            ),
            const Divider(indent: 16, endIndent: 16),
          ],
          if (folders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20.0,
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
                  final isCurrentFolder = widget.note.folderId == folder.key;
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
                    trailing: isCurrentFolder
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (!isCurrentFolder) {
                        noteProvider.addNoteToFolder(widget.note, folder);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.t('folder.selected'),
                              style: const TextStyle(),
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.viewPaddingOf(sheetContext).bottom),
        ],
      ),
    );
  }

  Future<void> _showDesktopContextMenu(Offset globalPosition) async {
    final l10n = context.l10n;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final action = await showMenu<_NoteMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: _NoteMenuAction.edit,
          child: Row(
            children: [
              const Icon(FluentIcons.edit_24_regular, size: 18),
              const SizedBox(width: 8),
              Text(l10n.t('common.edit')),
            ],
          ),
        ),
        PopupMenuItem(
          value: _NoteMenuAction.archive,
          child: Row(
            children: [
              const Icon(FluentIcons.archive_24_regular, size: 18),
              const SizedBox(width: 8),
              Text(l10n.t('notes.archive')),
            ],
          ),
        ),
        if (widget.note.folderId != null)
          PopupMenuItem(
            value: _NoteMenuAction.removeFromFolder,
            child: Row(
              children: [
                const Icon(FluentIcons.desktop_24_regular, size: 18),
                const SizedBox(width: 8),
                Text(l10n.t('notes.moveToDesktop')),
              ],
            ),
          ),
        PopupMenuItem(
          value: _NoteMenuAction.moveToFolder,
          child: Row(
            children: [
              const Icon(FluentIcons.folder_24_regular, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.note.folderId != null
                    ? l10n.t('folder.moveTo')
                    : l10n.t('folder.addTo'),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _NoteMenuAction.delete,
          child: Row(
            children: [
              const Icon(
                FluentIcons.delete_24_regular,
                size: 18,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.t('common.delete'),
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );

    if (action != null && mounted) {
      switch (action) {
        case _NoteMenuAction.edit:
          _editNote();
          break;
        case _NoteMenuAction.archive:
          _archiveNote();
          break;
        case _NoteMenuAction.removeFromFolder:
          _removeFromFolder();
          break;
        case _NoteMenuAction.moveToFolder:
          _showFolderSelectionSheet();
          break;
        case _NoteMenuAction.delete:
          _deleteNote();
          break;
      }
    }
  }

  void _showMobileOptionsDialog() {
    final l10n = context.l10n;
    final themeProvider = context.read<ThemeProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(l10n.t('notes.options'), style: const TextStyle()),
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
                    side: const BorderSide(color: Colors.green, width: 2),
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    l10n.t('common.cancel'),
                    style: const TextStyle(color: Colors.green, fontSize: 18),
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
                    Navigator.pop(dialogContext);
                    _archiveNote();
                  },
                  child: Text(
                    l10n.t('notes.archive'),
                    style: const TextStyle(fontSize: 18, color: Colors.white),
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
                      Navigator.pop(dialogContext);
                      _removeFromFolder();
                    },
                    child: Text(
                      l10n.t('notes.moveToDesktop'),
                      style: const TextStyle(fontSize: 18, color: Colors.white),
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
                    Navigator.pop(dialogContext);
                    _showFolderSelectionSheet();
                  },
                  child: Text(
                    widget.note.folderId != null
                        ? l10n.t('folder.moveTo')
                        : l10n.t('folder.addTo'),
                    style: TextStyle(
                      fontSize: 18,
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
                    Navigator.pop(dialogContext);
                    _deleteNote();
                  },
                  child: Text(
                    l10n.t('common.delete'),
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final note = widget.note;
    final l10n = context.l10n;
    final hasAudio = note.audioNotes?.isNotEmpty ?? false;
    final hasAttachments = note.attachments?.isNotEmpty ?? false;
    final hasCustomCardColor =
        note.usesCustomBackground && note.backgroundColorValue != null;
    final customCardColor = hasCustomCardColor
        ? Color(note.backgroundColorValue!)
        : null;
    final isDark = theme.brightness == Brightness.dark;
    final isOled = themeProvider.isOled;
    final colorScheme = theme.colorScheme;

    // Material 3's dark scaffolding is intentionally very low-contrast, so
    // cards need a lighter surface and a visible outline to stand out. OLED
    // keeps a near-black background, hence the extra surface step there.
    final cardColor =
        customCardColor ??
        (isOled
            ? colorScheme.surfaceContainerHighest
            : isDark
            ? colorScheme.surfaceContainerHigh
            : theme.cardColor);
    final cardBorderColor = hasCustomCardColor
        ? Colors.transparent
        : isDark
        ? Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.22),
            colorScheme.outlineVariant,
          )
        : colorScheme.outlineVariant.withValues(alpha: 0.55);
    final cardRadius = BorderRadius.circular(15);
    final defaultTextColor =
        customCardColor != null && customCardColor.computeLuminance() > 0.5
        ? Colors.black
        : theme.colorScheme.onSurface;
    final textColor = note.usesCustomTextColor && note.textColorValue != null
        ? Color(note.textColorValue!)
        : defaultTextColor;
    final title = note.title.trim();
    final displayTitle = title.isNotEmpty
        ? note.title
        : hasAudio && hasAttachments
        ? l10n.t('notes.audioAndFiles')
        : hasAudio
        ? l10n.t('notes.audio')
        : hasAttachments
        ? l10n.t('notes.files')
        : l10n.t('notes.untitled');
    final plainContent = NoteContent.plainText(note.content);

    return Listener(
      onPointerDown: (event) => _lastPointerKind = event.kind,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: cardBorderColor, width: 1.2),
        ),
        elevation: isDark ? 0 : 2,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        child: InkWell(
          borderRadius: cardRadius,
          onTap: _editNote,
          onSecondaryTapDown: (details) {
            _showDesktopContextMenu(details.globalPosition);
          },
          onLongPress: () {
            if (_isDesktopPlatform ||
                _lastPointerKind == PointerDeviceKind.mouse) {
              return;
            }
            _showMobileOptionsDialog();
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
                const SizedBox(height: 2),
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
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    plainContent.isEmpty && (hasAudio || hasAttachments)
                        ? l10n.t('notes.noText')
                        : plainContent,
                    style: TextStyle(
                      color: plainContent.isEmpty
                          ? textColor.withValues(alpha: 0.65)
                          : textColor,
                      fontFamilyFallback: const ['Apple'],
                      fontSize: 14,
                      fontStyle: plainContent.isEmpty
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
                          FluentIcons.mic_24_regular,
                          '${note.audioNotes!.length}',
                          textColor,
                        ),
                      if (hasAttachments)
                        _mediaBadge(
                          FluentIcons.attach_24_regular,
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
          Text(count, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
