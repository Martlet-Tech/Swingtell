import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/reading_progress.dart';
import '../services/file_parser/epub_parser.dart';
import '../services/file_parser/parser_base.dart';
import '../services/storage/database.dart';
import '../services/storage/progress_repository.dart';
import '../utils/app_logger.dart';
import 'reading_progress_controller.dart';

final readerProvider =
    StateNotifierProvider.family<ReaderNotifier, ReaderState, String>(
  (ref, bookId) => ReaderNotifier(bookId),
);

class ReaderState {
  final Book? book;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final int charOffset;
  final double totalProgress;
  final String currentContent;
  final List<TextBlock> currentBlocks;
  final bool isLoading;
  final String? error;
  final bool isPlaying;
  final bool isPaused;
  final double speed;

  const ReaderState({
    this.book,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.charOffset = 0,
    this.totalProgress = 0.0,
    this.currentContent = '',
    this.currentBlocks = const [],
    this.isLoading = false,
    this.error,
    this.isPlaying = false,
    this.isPaused = false,
    this.speed = 1.0,
  });

  ReaderState copyWith({
    Book? book,
    List<Chapter>? chapters,
    int? currentChapterIndex,
    int? charOffset,
    double? totalProgress,
    String? currentContent,
    List<TextBlock>? currentBlocks,
    bool? isLoading,
    String? error,
    bool? isPlaying,
    bool? isPaused,
    double? speed,
  }) =>
      ReaderState(
        book: book ?? this.book,
        chapters: chapters ?? this.chapters,
        currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
        charOffset: charOffset ?? this.charOffset,
        totalProgress: totalProgress ?? this.totalProgress,
        currentContent: currentContent ?? this.currentContent,
        currentBlocks: currentBlocks ?? this.currentBlocks,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        isPlaying: isPlaying ?? this.isPlaying,
        isPaused: isPaused ?? this.isPaused,
        speed: speed ?? this.speed,
      );
}

class ReaderNotifier extends StateNotifier<ReaderState> {
  final String bookId;
  final EpubParser _parser = EpubParser();
  final ProgressRepository _repo = ProgressRepository();
  ReadingProgressController? _progressController;
  Timer? _progressTimer;

  ReaderNotifier(this.bookId) : super(const ReaderState(isLoading: true));

  Future<void> loadBook() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final bookData = await DatabaseService.getBook(bookId);
      if (bookData == null) {
        state = state.copyWith(isLoading: false, error: 'Book not found');
        return;
      }
      final book = Book.fromMap(bookData);

      final chapterData = await DatabaseService.getChapters(bookId);
      final chapters = chapterData.map((m) => Chapter.fromMap(m)).toList();

      final savedProgress = await _repo.load(bookId);
      final initialProgress = savedProgress ?? ReadingProgress(
        bookId: bookId,
        chapterIndex: 0,
        charOffset: 0,
        totalProgress: 0.0,
        lastReadAt: DateTime.now(),
      );

      _progressController = ReadingProgressController(
        repo: _repo,
        initial: initialProgress,
      );

      final chapterIndex = initialProgress.chapterIndex;
      final charOffset = initialProgress.charOffset;

      List<TextBlock> blocks = [];
      if (chapters.isNotEmpty && chapterIndex < chapters.length) {
        blocks = await _parser.getChapterBlocks(book.filePath, chapterIndex);
      }

      // Recalculate totalProgress from chapterIndex + charOffset instead of
      // trusting possibly-corrupt DB value (e.g. from the old _loadChapter bug).
      final actualTotalProgress = _computeTotalProgress(chapterIndex, charOffset);

      state = ReaderState(
        book: book,
        chapters: chapters,
        currentChapterIndex: chapterIndex,
        charOffset: charOffset,
        totalProgress: actualTotalProgress,
        currentContent: blocks.map((b) => b.text).join('\n'),
        currentBlocks: blocks,
        isLoading: false,
        speed: state.speed,
      );

      AppLogger.instance.info('Book loaded: ${book.title}, chapter ${chapterIndex + 1}/${chapters.length}, '
          'charOffset=$charOffset, progressData=${savedProgress != null ? "found" : "none"}');
      _startProgressTimer();
    } catch (e) {
      AppLogger.instance.error('Book load failed', e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadChapter(int index) async {
    if (state.book == null) return;
    final blocks = await _parser.getChapterBlocks(state.book!.filePath, index);
    final totalProgress = (state.chapters.length > 0) ? index / state.chapters.length : 0.0;
    state = state.copyWith(
      currentChapterIndex: index,
      charOffset: 0,
      currentContent: blocks.map((b) => b.text).join('\n'),
      currentBlocks: blocks,
      totalProgress: totalProgress,
    );
    await _progressController?.seekTo(0, totalProgress);
    AppLogger.instance.info('Chapter loaded: ${index + 1}/${state.chapters.length}');
  }

  Future<void> jumpToChapter(int index) async {
    if (state.book == null || index < 0 || index >= state.chapters.length) return;
    await _loadChapter(index);
  }

  Future<void> nextChapter() async {
    if (state.book == null || state.currentChapterIndex >= state.chapters.length - 1) return;
    await _loadChapter(state.currentChapterIndex + 1);
  }

  Future<void> prevChapter() async {
    if (state.book == null || state.currentChapterIndex <= 0) return;
    await _loadChapter(state.currentChapterIndex - 1);
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed);
  }

  void play() {
    state = state.copyWith(isPlaying: true, isPaused: false);
  }

  void pause() {
    state = state.copyWith(isPlaying: false, isPaused: true);
    _saveProgressImmediately();
  }

  void stop() {
    state = state.copyWith(isPlaying: false, isPaused: false);
  }

  /// Public save trigger — let the UI layer save after each sentence advance.
  Future<void> saveProgress() => _saveProgressImmediately();

  void updateCharOffset(int offset) {
    if (state.book == null) return;
    final totalProgress = _computeTotalProgress(state.currentChapterIndex, offset);
    _progressController?.advance(offset, totalProgress);
    state = state.copyWith(
      charOffset: offset,
      totalProgress: totalProgress.clamp(0.0, 1.0),
    );
  }

  double _computeTotalProgress(int chapterIndex, int charOffset) {
    final chapter = state.chapters.isNotEmpty && chapterIndex < state.chapters.length
        ? state.chapters[chapterIndex]
        : null;
    final totalChars = chapter?.charCount ?? 1;
    final chapterProgress = totalChars > 0 ? charOffset / totalChars : 0.0;
    final total = state.chapters.length;
    return ((chapterIndex + chapterProgress) / (total > 0 ? total : 1)).clamp(0.0, 1.0);
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveProgressImmediately();
    });
  }

  Future<void> _saveProgressImmediately() async {
    if (state.book == null || _progressController == null) return;
    try {
      await _progressController!.persist();
    } catch (e) {
      AppLogger.instance.error('Progress save failed', e);
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _progressController?.dispose();
    super.dispose();
  }
}
