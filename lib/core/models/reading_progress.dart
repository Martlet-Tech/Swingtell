import 'package:hive/hive.dart';

part 'reading_progress.g.dart';

@HiveType(typeId: 1)
class ReadingProgress extends HiveObject {
  @HiveField(0) late String bookId;
  @HiveField(1) int chapterIndex = 0;
  @HiveField(2) int charOffset = 0;
  @HiveField(3) double percentage = 0.0;
  @HiveField(4) late DateTime updatedAt;
}
