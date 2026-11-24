import 'package:flutter/material.dart';
import 'package:inkflow/hive_models/save_note.dart';
import 'package:intl/intl.dart';

/// A group of notes that belong to one local calendar day.
class NoteDateGroup {
  const NoteDateGroup({required this.date, required this.notes});

  /// Local midnight of the group's calendar date.
  final DateTime date;
  final List<SaveNote> notes;
}

/// Deterministic note ordering and date grouping.
///
/// The primary key is [SaveNote.createdAt] (newest first). Notes with the same
/// timestamp are ordered by their Hive key, which is stable and monotonic for
/// notes created in this app. The original list index is the final tie-breaker,
/// so a list never shuffles between rebuilds even if legacy data contains
/// identical notes.
class NoteSorting {
  NoteSorting._();

  static int compareNewestFirst(SaveNote a, SaveNote b) {
    final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    final byDate = bCreated.compareTo(aCreated);
    if (byDate != 0) return byDate;

    final aKey = a.key is num ? (a.key as num).toDouble() : -1.0;
    final bKey = b.key is num ? (b.key as num).toDouble() : -1.0;
    final byKey = bKey.compareTo(aKey);
    if (byKey != 0) return byKey;

    final byTitle = a.title.compareTo(b.title);
    if (byTitle != 0) return byTitle;

    return a.content.compareTo(b.content);
  }

  /// Default sort order: newest created notes first.
  static List<SaveNote> newestFirst(Iterable<SaveNote> notes) {
    final indexed = notes.toList().asMap().entries.toList();
    indexed.sort((left, right) {
      final byNote = compareNewestFirst(left.value, right.value);
      if (byNote != 0) return byNote;

      // Guarantee a stable order even when two notes are truly identical.
      return left.key.compareTo(right.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  /// Groups already-filtered notes by their local creation date.
  ///
  /// Notes are never duplicated: each note appears in exactly one group.
  static List<NoteDateGroup> groupByLocalDate(Iterable<SaveNote> notes) {
    final groups = <NoteDateGroup>[];

    for (final note in newestFirst(notes)) {
      final created = note.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final local = created.toLocal();
      final date = DateTime(local.year, local.month, local.day);

      if (groups.isEmpty ||
          groups.last.date.year != date.year ||
          groups.last.date.month != date.month ||
          groups.last.date.day != date.day) {
        groups.add(NoteDateGroup(date: date, notes: [note]));
      } else {
        groups.last.notes.add(note);
      }
    }

    return groups;
  }
}

/// Formats a date group header using the active app locale's CLDR data.
/// Russian example: `16 ноября 2026`.
String formatNoteDateHeader(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat('d MMMM y', locale).format(date);
}

/// Formats a full date and time for note creation / details.
/// Russian example: `16 ноября 2026, 14:30`.
String formatNoteDateTime(BuildContext context, DateTime dateTime) {
  final locale = Localizations.localeOf(context).toString();
  final local = dateTime.toLocal();
  final dateStr = DateFormat('d MMMM y', locale).format(local);
  final timeStr = DateFormat('HH:mm', locale).format(local);
  return '$dateStr, $timeStr';
}

/// Formats time of day for auto-save status.
/// Russian example: `19:41`.
String formatNoteTime(BuildContext context, DateTime dateTime) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat('HH:mm', locale).format(dateTime.toLocal());
}
