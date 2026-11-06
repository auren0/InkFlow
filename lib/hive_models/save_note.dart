import 'package:hive/hive.dart';

part 'save_note.g.dart';

@HiveType(typeId: 0)
class SaveNote extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String content;

  @HiveField(2)
  int? folderId;

  @HiveField(3)
  String? backgroundImagePath;

  @HiveField(4)
  int? textColorValue;

  @HiveField(5)
  int? backgroundColorValue;

  @HiveField(6)
  List<String>? audioNotes;

  @HiveField(7)
  List<String>? audioTitles;

  @HiveField(8)
  List<String>? attachments;

  @HiveField(9)
  bool? hasCustomBackground;

  @HiveField(10)
  bool? hasCustomTextColor;

  SaveNote({
    required this.title,
    required this.content,
    this.folderId,
    this.backgroundImagePath,
    this.textColorValue,
    this.backgroundColorValue,
    this.audioNotes,
    this.audioTitles,
    this.attachments,
    this.hasCustomBackground,
    this.hasCustomTextColor,
  });

  /// Старые заметки всегда сохраняли жёлтый фон, даже если его не выбирали.
  bool get usesCustomBackground {
    if (hasCustomBackground != null) return hasCustomBackground!;
    return backgroundColorValue != null && backgroundColorValue != 0xFFFFEB3B;
  }

  /// Старые заметки всегда сохраняли чёрный цвет текста, даже если его не выбирали.
  bool get usesCustomTextColor {
    if (hasCustomTextColor != null) return hasCustomTextColor!;
    return textColorValue != null && textColorValue != 0xFF000000;
  }
}
