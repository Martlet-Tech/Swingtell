import 'package:hive/hive.dart';

part 'chat_session.g.dart';

@HiveType(typeId: 3)
class ChatSession extends HiveObject {
  @HiveField(0) late String characterId;
  @HiveField(1) late DateTime lastActiveAt;
  @HiveField(2) int messageCount = 0;
}
