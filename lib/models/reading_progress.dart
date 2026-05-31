class ReadingProgress {
  final String bookId;
  final int chapterIndex;
  final int charOffset;
  final double totalProgress;
  final DateTime lastReadAt;
  final int totalReadingSeconds;
  final String? aiRecap;
  final String? pronunciationVersion;

  ReadingProgress({
    required this.bookId,
    required this.chapterIndex,
    required this.charOffset,
    required this.totalProgress,
    required this.lastReadAt,
    this.totalReadingSeconds = 0,
    this.aiRecap,
    this.pronunciationVersion,
  });

  Map<String, dynamic> toMap() => {
        'book_id': bookId,
        'chapter_index': chapterIndex,
        'char_offset': charOffset,
        'total_progress': totalProgress,
        'last_read_at': lastReadAt.millisecondsSinceEpoch,
        'total_reading_seconds': totalReadingSeconds,
        'ai_recap': aiRecap,
        'pronunciation_version': pronunciationVersion,
      };

  factory ReadingProgress.fromMap(Map<String, dynamic> m) => ReadingProgress(
        bookId: m['book_id'] as String,
        chapterIndex: m['chapter_index'] as int? ?? 0,
        charOffset: m['char_offset'] as int? ?? 0,
        totalProgress: (m['total_progress'] as num?)?.toDouble() ?? 0.0,
        lastReadAt: DateTime.fromMillisecondsSinceEpoch(
            m['last_read_at'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        totalReadingSeconds: m['total_reading_seconds'] as int? ?? 0,
        aiRecap: m['ai_recap'] as String?,
        pronunciationVersion: m['pronunciation_version'] as String?,
      );

  ReadingProgress copyWith({
    int? chapterIndex,
    int? charOffset,
    double? totalProgress,
    DateTime? lastReadAt,
    int? totalReadingSeconds,
  }) =>
      ReadingProgress(
        bookId: bookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        charOffset: charOffset ?? this.charOffset,
        totalProgress: totalProgress ?? this.totalProgress,
        lastReadAt: lastReadAt ?? this.lastReadAt,
        totalReadingSeconds: totalReadingSeconds ?? this.totalReadingSeconds,
        aiRecap: aiRecap,
        pronunciationVersion: pronunciationVersion,
      );
}
