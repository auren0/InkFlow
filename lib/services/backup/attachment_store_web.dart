import 'dart:convert';
import 'dart:typed_data';

import 'package:inkflow/services/backup/attachment_store_base.dart';
import 'package:path/path.dart' as p;

AttachmentStore createAttachmentStore() => WebAttachmentStore();

/// Web attachments are stored as data URIs inside the note, because browsers
/// do not grant persistent access to arbitrary local file paths. The data URI
/// keeps the original filename in its fragment, and can be downloaded or
/// opened by the browser.
class WebAttachmentStore implements AttachmentStore {
  @override
  Future<Uint8List?> read(String path) async {
    if (!path.startsWith('data:')) return null;

    try {
      final hashIndex = path.indexOf('#');
      final withoutFragment = hashIndex >= 0
          ? path.substring(0, hashIndex)
          : path;
      final commaIndex = withoutFragment.indexOf(',');
      if (commaIndex < 0) return null;

      final header = withoutFragment.substring(0, commaIndex);
      final payload = withoutFragment.substring(commaIndex + 1);
      if (header.contains(';base64')) {
        return base64Decode(payload);
      }
      return Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> persist(String fileName, Uint8List bytes) async {
    final safeName = _safeFileName(fileName);
    final mime = _mimeForName(safeName);
    final encoded = base64Encode(bytes);
    return 'data:$mime;base64,$encoded#${Uri.encodeComponent(safeName)}';
  }

  @override
  Future<void> delete(String path) async {
    // Data URIs live inside the note record itself. Nothing to delete outside
    // the database transaction that owns the note.
  }

  @override
  String displayName(String path) {
    if (path.startsWith('data:')) {
      final hashIndex = path.indexOf('#');
      if (hashIndex >= 0) {
        final name = Uri.decodeComponent(path.substring(hashIndex + 1));
        if (name.isNotEmpty) return name;
      }
      return 'attachment';
    }

    final normalized = path.replaceAll('\\', '/');
    final name = p.basename(normalized);
    return name.isEmpty ? 'attachment' : name;
  }

  String _safeFileName(String fileName) {
    final normalized = fileName.replaceAll('\\', '/');
    var name = p.basename(normalized);
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    if (name.isEmpty || name == '.' || name == '..') return 'attachment';
    if (name.length > 150) {
      final extension = p.extension(name);
      name = name.substring(0, 150 - extension.length) + extension;
    }
    return name;
  }

  String _mimeForName(String name) {
    final extension = p.extension(name).toLowerCase();
    return switch (extension) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.pdf' => 'application/pdf',
      '.txt' => 'text/plain',
      '.json' => 'application/json',
      '.mp3' => 'audio/mpeg',
      '.m4a' => 'audio/mp4',
      '.wav' => 'audio/wav',
      '.ogg' => 'audio/ogg',
      _ => 'application/octet-stream',
    };
  }
}
