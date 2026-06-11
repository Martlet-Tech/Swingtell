part of 'news_topic.dart';

class NewsTopicAdapter extends TypeAdapter<NewsTopic> {
  @override
  final int typeId = 4;

  @override
  NewsTopic read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NewsTopic()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..prompt = fields[2] as String
      ..createdAt = fields[3] as DateTime;
  }

  @override
  void write(BinaryWriter writer, NewsTopic obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.prompt)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsTopicAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
