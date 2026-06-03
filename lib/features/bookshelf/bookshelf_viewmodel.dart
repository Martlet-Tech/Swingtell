import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/models/book.dart';
import '../../core/models/reading_progress.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/epub_service.dart';
import '../../core/services/progress_service.dart';

class BookshelfViewModel extends ChangeNotifier {
  final StorageService _storageService;
  final EpubService _epubService;
  final ProgressService _progressService;

  List<Book> _books = [];
  Map<String, ReadingProgress> _progressMap = {};

  List<Book> get books => _books;
  Map<String, ReadingProgress> get progressMap => _progressMap;

  BookshelfViewModel({
    required StorageService storageService,
    required EpubService epubService,
    required ProgressService progressService,
  })  : _storageService = storageService,
        _epubService = epubService,
        _progressService = progressService;

  void load() {
    _books = _storageService.getAllBooks();
    _progressMap = _progressService.getAllProgress();
    notifyListeners();
  }

  Future<void> importBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );
    if (result == null || result.files.isEmpty) return;

    final sourcePath = result.files.first.path!;
    try {
      final destPath = await _storageService.importEpubFile(sourcePath);
      final book = await _epubService.parseMetadata(destPath);
      await _storageService.saveBook(book);
      load();
    } catch (e) {
      debugPrint('[Bookshelf] 导入失败: $e');
      rethrow;
    }
  }

  Future<void> deleteBook(String bookId) async {
    await _storageService.removeBook(bookId);
    load();
  }
}
