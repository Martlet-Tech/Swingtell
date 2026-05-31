enum BookFormat { epub, txt, pdf }

class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final BookFormat format;
  final int fileSize;
  final String? coverPath;
  final int totalChapters;
  final DateTime createdAt;
  final DateTime updatedAt;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.format,
    required this.fileSize,
    this.coverPath,
    required this.totalChapters,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'file_path': filePath,
        'file_format': format.name,
        'file_size': fileSize,
        'cover_path': coverPath,
        'total_chapters': totalChapters,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Book.fromMap(Map<String, dynamic> m) => Book(
        id: m['id'] as String,
        title: m['title'] as String,
        author: m['author'] as String? ?? '',
        filePath: m['file_path'] as String,
        format: BookFormat.values.byName(m['file_format'] as String),
        fileSize: m['file_size'] as int? ?? 0,
        coverPath: m['cover_path'] as String?,
        totalChapters: m['total_chapters'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      );

  Book copyWith({
    String? title,
    String? author,
    int? totalChapters,
    DateTime? updatedAt,
  }) =>
      Book(
        id: id,
        title: title ?? this.title,
        author: author ?? this.author,
        filePath: filePath,
        format: format,
        fileSize: fileSize,
        coverPath: coverPath,
        totalChapters: totalChapters ?? this.totalChapters,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
