import 'package:hive/hive.dart';

part 'news_topic.g.dart';

@HiveType(typeId: 4)
class NewsTopic extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String name;
  @HiveField(2) late String prompt;
  @HiveField(3) late DateTime createdAt;
}
