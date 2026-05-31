class ChapterContent {
  final int index;
  final String title;
  final String content;

  ChapterContent({
    required this.index,
    required this.title,
    required this.content,
  });
}

class TextBlock {
  final String text;
  final double scale; // font size multiplier: 1.0 = body text

  const TextBlock({required this.text, this.scale = 1.0});
}

abstract class BookParser {
  Future<BookMeta> parseMeta(String filePath);
  Future<List<ChapterItem>> parseChapters(String filePath);
  Future<String> getChapterContent(String filePath, int chapterIndex);
  Future<List<TextBlock>> getChapterBlocks(String filePath, int chapterIndex);
}

class BookMeta {
  final String title;
  final String author;

  BookMeta({required this.title, this.author = ''});
}

class ChapterItem {
  final int index;
  final String title;
  final String? href;

  ChapterItem({required this.index, required this.title, this.href});
}
