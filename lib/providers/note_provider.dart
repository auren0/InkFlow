import 'package:flutter/material.dart';
import 'package:note_app/hive_models/save_folder.dart';
import 'package:note_app/hive_models/save_note.dart';
import 'package:note_app/services/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NoteProvider with ChangeNotifier {
  final Box<SaveNote> _notesBox = HiveService.getNotesBox();
  final Box<SaveNote> _archiveBox = HiveService.getArchiveBox();
  final Box<SaveNote> _trashNotesBox = HiveService.getTrashNotesBox();
  final Box<SaveFolder> _trashFoldersBox = HiveService.getTrashFoldersBox();
  final Box<SaveFolder> _foldersBox = HiveService.getFoldersBox();

  List<SaveNote> get notes => _notesBox.values.toList();

  List<SaveNote> get archive => _archiveBox.values.toList();

  List<SaveNote> get trashNotes => _trashNotesBox.values.toList();

  List<SaveFolder> get trashFolders => _trashFoldersBox.values.toList();

  List<SaveFolder> get folders => _foldersBox.values.toList();

  // ============== Notes Methods ==============
  Future<void> addNote(SaveNote note) async {
    await _notesBox.add(note);
    notifyListeners();
  }

  Future<void> updateNote(SaveNote oldNote, SaveNote newNote) async {
    oldNote
      ..title = newNote.title
      ..content = newNote.content
      ..folderId = newNote.folderId
      ..backgroundImagePath = newNote.backgroundImagePath
      ..textColorValue = newNote.textColorValue
      ..backgroundColorValue = newNote.backgroundColorValue
      ..audioNotes = newNote.audioNotes
      ..audioTitles = newNote.audioTitles
      ..attachments = newNote.attachments
      ..hasCustomBackground = newNote.hasCustomBackground
      ..hasCustomTextColor = newNote.hasCustomTextColor;
    await oldNote.save();
    notifyListeners();
  }

  Future<void> saveNoteChanges(SaveNote note) async {
    await note.save();
    notifyListeners();
  }

  void addNoteToFolder(SaveNote note, SaveFolder folder) async {
    note.folderId = folder.key as int;
    await note.save();
    notifyListeners();
  }

  void removeNoteFromFolder(SaveNote note) async {
    note.folderId = null;
    await note.save();
    notifyListeners();
  }

  void moveNote(SaveNote note, Box<SaveNote> to) async {
    final newNote = SaveNote(
      title: note.title,
      content: note.content,
      folderId: note.folderId,
      backgroundImagePath: note.backgroundImagePath,
      backgroundColorValue: note.backgroundColorValue,
      textColorValue: note.textColorValue,
      audioNotes: note.audioNotes?.toList(),
      audioTitles: note.audioTitles?.toList(),
      attachments: note.attachments?.toList(),
      hasCustomBackground: note.hasCustomBackground,
      hasCustomTextColor: note.hasCustomTextColor,
    );
    await to.add(newNote);
    await note.delete();
    notifyListeners();
  }

  void moveFolder(SaveFolder folder, Box<SaveFolder> to) async {
    final newFolder = SaveFolder(
      title: folder.title,
      colorValue: folder.colorValue,
    );
    await to.add(newFolder);
    await folder.delete();
    notifyListeners();
  }

  void deleteNoteForever(SaveNote note) async {
    await note.delete();
    notifyListeners();
  }

  void deleteFolderForever(SaveFolder folder) async {
    await folder.delete();
    notifyListeners();
  }

  List<SaveNote> getNotesByFolder(int folderId) {
    return notes.where((note) => note.folderId == folderId).toList();
  }

  void addToArchive(SaveNote note) => moveNote(note, _archiveBox);

  void restoreFromArchive(SaveNote note) => moveNote(note, _notesBox);

  void moveNoteToTrash(SaveNote note) => moveNote(note, _trashNotesBox);

  void moveFolderToTrash(SaveFolder folder) =>
      moveFolder(folder, _trashFoldersBox);

  void restoreNoteFromTrash(SaveNote note) => moveNote(note, _notesBox);

  void restoreFolderFromTrash(SaveFolder folder) =>
      moveFolder(folder, _foldersBox);

  // void addToArchive(SaveNote note) async {
  //   await _archiveBox.add(note);
  //   await note.delete();
  //   notifyListeners();
  // }

  // void restoreFromArchive(SaveNote note) async {
  //   await _notesBox.add(note);
  //   await note.delete();
  //   notifyListeners();
  // }

  // void moveToTrash(SaveNote note) async {
  //   await _trashBox.add(note);
  //   await note.delete();
  //   notifyListeners();
  // }

  // void restoreFromTrash(SaveNote note) async {
  //   await _notesBox.add(note);
  //   await note.delete();
  //   notifyListeners();
  // }

  // ============== Folders Methods ==============
  Future<void> addFolder(SaveFolder folder) async {
    await _foldersBox.add(folder);
    notifyListeners();
  }

  Future<void> saveFolderChanges(SaveFolder folder) async {
    await folder.save();
    notifyListeners();
  }

  Future<void> deleteFolder(SaveFolder folder) async {
    await folder.delete();
    notifyListeners();
  }
}
