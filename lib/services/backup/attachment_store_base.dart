import 'dart:typed_data';

/// Cross-platform attachment storage used by the backup service.
///
/// The backup code itself never imports `dart:io`; native and web
/// implementations are selected with a conditional import.
abstract class AttachmentStore {
  /// Reads a note attachment by its stored path. Returns `null` when the file
  /// is missing or cannot be read on the current platform.
  Future<Uint8List?> read(String path);

  /// Persists imported bytes and returns the path/URI to store in a note.
  Future<String> persist(String fileName, Uint8List bytes);

  /// Removes a file created by [persist] during a failed import.
  Future<void> delete(String path);

  /// A short, human-readable name for UI lists and archive entries.
  String displayName(String path);
}
