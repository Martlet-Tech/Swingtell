import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/reading_progress.dart';
import '../models/reader_settings.dart';

class StorageService {
  late Box<Book> _bookBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(BookAdapter());
    Hive.registerAdapter(ReadingProgressAdapter());
    Hive.registerAdapter(ReaderSettingsAdapter());
    _bookBox = await Hive.openBox<Book>('books');
    await Hive.openBox<ReadingProgress>('progress');
    await Hive.openBox<ReaderSettings>('settings');
  }

  Future<Directory> getBooksDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/books');
    if (!await booksDir.exists()) await booksDir.create(recursive: true);
    return booksDir;
  }

  Future<String> importEpubFile(String sourcePath) async {
    final booksDir = await getBooksDirectory();
    final fileName = path.basename(sourcePath);
    final destPath = '${booksDir.path}/$fileName';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  List<Book> getAllBooks() => _bookBox.values.toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  Future<void> saveBook(Book book) => _bookBox.put(book.id, book);

  Future<void> removeBook(String bookId) async {
    final book = _bookBox.get(bookId);
    if (book != null) {
      final file = File(book.filePath);
      if (await file.exists()) await file.delete();
      await _bookBox.delete(bookId);
    }
  }
}
