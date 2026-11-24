import 'dart:io';
import 'dart:typed_data';

import 'package:inkflow/services/backup/attachment_store_base.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

AttachmentStore createAttachmentStore() => IoAttachmentStore();

class IoAttachmentStore implements AttachmentStore {
  static const String _folderName = 'attachments';
  static int _sequence = 0;

  @override
  Future<Uint8List?> read(String path) async {
    if (path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> persist(String fileName, Uint8List bytes) async {
    final directory = await _attachmentsDirectory();
    final safeName = _safeFileName(fileName);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final destination = p.join(
      directory.path,
      '${stamp}_${_sequence++}_$safeName',
    );

    final file = File(destination);
    await file.writeAsBytes(bytes, flush: true);
    return destination;
  }

  @override
  Future<void> delete(String path) async {
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Rollback must not mask the original import error.
    }
  }

  @override
  String displayName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = p.basename(normalized);
    return name.isEmpty ? 'attachment' : name;
  }

  Future<Directory> _attachmentsDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, _folderName));
    await directory.create(recursive: true);
    return directory;
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
}
