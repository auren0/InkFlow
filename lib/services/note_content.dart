import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

/// Serialization helpers for note contents.
///
/// Rich notes are stored as a Quill Delta JSON array in [SaveNote.content].
/// Plain-text notes created by older app versions are auto-detected and
/// wrapped into a Delta document when they are opened, without modifying the
/// stored value until the user edits the note.
class NoteContent {
  NoteContent._();

  /// Parses a stored note body into a Quill [Document].
  static Document parse(String? raw) {
    final content = raw ?? '';
    if (content.trim().isEmpty) {
      return Document();
    }

    final delta = _tryDecodeDelta(content);
    if (delta != null) {
      try {
        return Document.fromJson(delta);
      } catch (_) {
        // Corrupted or unsupported Delta: fall back to plain text instead of
        // losing the user's data.
      }
    }

    return _documentFromPlainText(content);
  }

  /// Serializes a [Document] into the string stored in Hive.
  static String encode(Document document) {
    return jsonEncode(document.toDelta().toJson());
  }

  /// Returns a plain-text representation for previews, search and export.
  static String plainText(String? raw) {
    final content = raw ?? '';
    if (content.trim().isEmpty) {
      return '';
    }

    final delta = _tryDecodeDelta(content);
    if (delta == null) {
      return content;
    }

    try {
      final text = Document.fromJson(delta).toPlainText();
      // Quill always keeps a trailing newline for the final line.
      return text.replaceAll(RegExp(r'\n+$'), '');
    } catch (_) {
      return content;
    }
  }

  static bool hasText(String? raw) {
    return plainText(raw).trim().isNotEmpty;
  }

  static List<dynamic>? _tryDecodeDelta(String raw) {
    final trimmed = raw.trimLeft();
    if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return _isValidDelta(decoded) ? decoded : null;
      }
      if (decoded is Map && decoded['ops'] is List) {
        final ops = decoded['ops'] as List;
        return _isValidDelta(ops) ? ops : null;
      }
    } catch (_) {
      // Not JSON - this is a legacy plain-text note.
    }

    return null;
  }

  static bool _isValidDelta(List<dynamic> delta) {
    if (delta.isEmpty) return false;
    return delta.every(
      (operation) => operation is Map && operation.containsKey('insert'),
    );
  }

  static Document _documentFromPlainText(String text) {
    final normalized = text.endsWith('\n') ? text : '$text\n';
    return Document.fromJson([
      {'insert': normalized},
    ]);
  }
}
