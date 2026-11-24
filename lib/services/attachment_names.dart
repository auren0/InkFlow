import 'package:path/path.dart' as p;

/// Returns a short display name for a stored attachment path.
///
/// Web imports keep attachments as data URIs with the original filename in the
/// URI fragment; native paths are converted with `path.basename`.
String attachmentDisplayName(String path) {
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

/// Returns an uppercase extension for display, or an empty string.
String attachmentExtensionLabel(String path) {
  final name = attachmentDisplayName(path);
  return p.extension(name).replaceFirst('.', '').toUpperCase();
}
