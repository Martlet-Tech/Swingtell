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
      ..ttsSpeechRate = fields[4] as double
      ..ttsPitch = fields[6] as double
      ..aiApiKey = fields[8] as String
      ..aiApiUrl = fields[9] as String
      ..aiModel = fields[10] as String
      ..keepScreenOn = fields[11] as bool? ?? false;
  }

  @override
  void write(BinaryWriter writer, ReaderSettings obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.fontFamily)
      ..writeByte(1)
      ..write(obj.fontSize)
      ..writeByte(2)
      ..write(obj.lineHeight)
      ..writeByte(3)
      ..write(obj.colorThemeIndex)
      ..writeByte(4)
      ..write(obj.ttsSpeechRate)
      ..writeByte(6)
      ..write(obj.ttsPitch)
      ..writeByte(8)
      ..write(obj.aiApiKey)
      ..writeByte(9)
      ..write(obj.aiApiUrl)
      ..writeByte(10)
      ..write(obj.aiModel)
      ..writeByte(11)
      ..write(obj.keepScreenOn);
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
