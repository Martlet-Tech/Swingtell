import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/reading_progress.dart';
import '../services/file_parser/epub_parser.dart';
import '../services/file_parser/parser_base.dart';
import '../services/storage/database.dart';

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

      final progressData = await DatabaseService.getProgress(bookId);
      int chapterIndex = 0;
      int charOffset = 0;
      if (progressData != null) {
        final prog = ReadingProgress.fromMap(progressData);
        chapterIndex = prog.chapterIndex;
        charOffset = prog.charOffset;
      }

      List<TextBlock> blocks = [];
      if (chapters.isNotEmpty && chapterIndex < chapters.length) {
        blocks = await _parser.getChapterBlocks(book.filePath, chapterIndex);
      }

      state = ReaderState(
        book: book,
        chapters: chapters,
        currentChapterIndex: chapterIndex,
        charOffset: charOffset,
        totalProgress: progressData != null
            ? (progressData['total_progress'] as num).toDouble()
            : 0.0,
        currentContent: blocks.map((b) => b.text).join('\n'),
        currentBlocks: blocks,
        isLoading: false,
        speed: state.speed,
      );

      _startProgressTimer();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadChapter(int index) async {
    if (state.book == null) return;
    final blocks = await _parser.getChapterBlocks(state.book!.filePath, index);
    final total = state.chapters.length;
    state = state.copyWith(
      currentChapterIndex: index,
      charOffset: 0,
      currentContent: blocks.map((b) => b.text).join('\n'),
      currentBlocks: blocks,
      totalProgress: total / (total > 0 ? total : 1),
    );
    _saveProgressImmediately();
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

  void updateCharOffset(int offset) {
    if (state.book == null) return;
    final chapter = state.chapters.isNotEmpty &&
            state.currentChapterIndex < state.chapters.length
        ? state.chapters[state.currentChapterIndex]
        : null;
    final totalChars = chapter?.charCount ?? 1;
    final chapterProgress = offset / totalChars;
    final total = state.chapters.length;
    final overall =
        (state.currentChapterIndex + chapterProgress) / (total > 0 ? total : 1);

    state = state.copyWith(
      charOffset: offset,
      totalProgress: overall.clamp(0.0, 1.0),
    );
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveProgressImmediately();
    });
  }

  Future<void> _saveProgressImmediately() async {
    if (state.book == null) return;
    await DatabaseService.saveProgress(ReadingProgress(
      bookId: bookId,
      chapterIndex: state.currentChapterIndex,
      charOffset: state.charOffset,
      totalProgress: state.totalProgress,
      lastReadAt: DateTime.now(),
      totalReadingSeconds: 0,
    ).toMap());
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _saveProgressImmediately();
    super.dispose();
  }
}
