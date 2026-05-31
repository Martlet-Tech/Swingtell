class Chapter {
  final String id;
  final String bookId;
  final int index;
  final String title;
  final String source; // 'format' (epub/pdf built-in) / 'ai' / 'rule'
  final int startPos;
  final int endPos;
  final int charCount;

  Chapter({
    required this.id,
    required this.bookId,
    required this.index,
    required this.title,
    this.source = 'format',
    required this.startPos,
    required this.endPos,
    required this.charCount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'book_id': bookId,
        'idx': index,
        'title': title,
        'source': source,
        'start_pos': startPos,
        'end_pos': endPos,
        'char_count': charCount,
      };

  factory Chapter.fromMap(Map<String, dynamic> m) => Chapter(
        id: m['id'] as String,
        bookId: m['book_id'] as String,
        index: m['idx'] as int,
        title: m['title'] as String? ?? '',
        source: m['source'] as String? ?? 'format',
        startPos: m['start_pos'] as int? ?? 0,
        endPos: m['end_pos'] as int? ?? 0,
        charCount: m['char_count'] as int? ?? 0,
      );
}
