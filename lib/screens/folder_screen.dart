import 'package:flutter/material.dart';
import 'package:inkflow/hive_models/save_folder.dart';
import 'package:inkflow/hive_models/save_note.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/note_provider.dart';
import 'package:inkflow/screens/home_screen.dart';
import 'package:inkflow/services/note_sorting.dart';
import 'package:inkflow/shared_preferences/note_settings_provider.dart';
import 'package:inkflow/widgets/date_group_header.dart';
import 'package:provider/provider.dart';

class FolderScreen extends StatelessWidget {
  final SaveFolder folder;
  const FolderScreen({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final noteSettings = context.watch<NoteSettingsProvider>();
    final notes = NoteSorting.newestFirst(
      noteProvider.getNotesByFolder(folder.key as int),
    );
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.t('folder.title', {'title': folder.title}),
          style: TextStyle(),
        ),
      ),
      body: notes.isEmpty
          ? Center(child: Text(l10n.t('folder.empty'), style: TextStyle()))
          : noteSettings.groupByDate
          ? _buildGrouped(context, notes, noteProvider)
          : _buildGrid(context, notes, noteProvider),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<SaveNote> notes,
    NoteProvider noteProvider,
  ) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomInset),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          childAspectRatio: 1,
        ),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return NoteCard(note: note, noteProvider: noteProvider);
        },
      ),
    );
  }

  Widget _buildGrouped(
    BuildContext context,
    List<SaveNote> notes,
    NoteProvider noteProvider,
  ) {
    final groups = NoteSorting.groupByLocalDate(notes);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 5,
      mainAxisSpacing: 5,
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
        SliverToBoxAdapter(child: SizedBox(height: 20 + bottomInset)),
      ],
    );
  }
}
