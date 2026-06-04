// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatSessionAdapter extends TypeAdapter<ChatSession> {
  @override
  final int typeId = 3;

  @override
  ChatSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatSession()
      ..characterId = fields[0] as String
      ..lastActiveAt = fields[1] as DateTime
      ..messageCount = fields[2] as int;
  }

  @override
  void write(BinaryWriter writer, ChatSession obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.characterId)
      ..writeByte(1)
      ..write(obj.lastActiveAt)
      ..writeByte(2)
      ..write(obj.messageCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
