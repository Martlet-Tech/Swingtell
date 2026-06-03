import 'package:hive/hive.dart';

part 'book.g.dart';

@HiveType(typeId: 0)
class Book extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String title;
  @HiveField(2) late String author;
  @HiveField(3) late String filePath;
  @HiveField(4) String? coverBase64;
  @HiveField(5) late DateTime addedAt;
}
