// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_folder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaveFolderAdapter extends TypeAdapter<SaveFolder> {
  @override
  final int typeId = 1;

  @override
  SaveFolder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaveFolder(title: fields[0] as String, colorValue: fields[1] as int);
  }

  @override
  void write(BinaryWriter writer, SaveFolder obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.colorValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveFolderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
