// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReaderSettingsAdapter extends TypeAdapter<ReaderSettings> {
  @override
  final int typeId = 2;

  @override
  ReaderSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReaderSettings()
      ..fontFamily = fields[0] as String
      ..fontSize = fields[1] as double
      ..lineHeight = fields[2] as double
      ..colorThemeIndex = fields[3] as int
      ..readingMode = fields[4] as String
      ..ttsSpeechRate = fields[5] as double
      ..ttsPitch = fields[6] as double
      ..ttsVolume = fields[7] as double;
  }

  @override
  void write(BinaryWriter writer, ReaderSettings obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.fontFamily)
      ..writeByte(1)
      ..write(obj.fontSize)
      ..writeByte(2)
      ..write(obj.lineHeight)
      ..writeByte(3)
      ..write(obj.colorThemeIndex)
      ..writeByte(4)
      ..write(obj.readingMode)
      ..writeByte(5)
      ..write(obj.ttsSpeechRate)
      ..writeByte(6)
      ..write(obj.ttsPitch)
      ..writeByte(7)
      ..write(obj.ttsVolume);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
