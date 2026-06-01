import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/chapter_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/reading_progress.dart';
import '../services/file_parser/epub_parser.dart';
import '../services/file_parser/parser_base.dart';
import '../services/tts/tts_base.dart';
import '../services/tts/tts_player.dart';
import '../services/tts/device_tts.dart';
import '../utils/app_logger.dart';
import 'reading_progress_controller.dart';
import 'repository_providers.dart';

final readerProvider =
    StateNotifierProvider.family<ReaderNotifier, ReaderState, String>(
  (ref, bookId) => ReaderNotifier(bookId, ref),
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
  final List<String> sentences;
  final List<double> sentenceScales;
  final List<bool> sentenceIsBlockStart;
  final int currentSentenceIndex;
  final bool autoNextChapter;

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
    this.sentences = const [],
    this.sentenceScales = const [],
    this.sentenceIsBlockStart = const [],
    this.currentSentenceIndex = 0,
    this.autoNextChapter = false,
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
    List<String>? sentences,
    List<double>? sentenceScales,
    List<bool>? sentenceIsBlockStart,
    int? currentSentenceIndex,
    bool? autoNextChapter,
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
        sentences: sentences ?? this.sentences,
        sentenceScales: sentenceScales ?? this.sentenceScales,
        sentenceIsBlockStart: sentenceIsBlockStart ?? this.sentenceIsBlockStart,
        currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
        autoNextChapter: autoNextChapter ?? this.autoNextChapter,
      );
}

class ReaderNotifier extends StateNotifier<ReaderState> {
  final String bookId;
  final Ref _ref;
  final EpubParser _parser = EpubParser();
  late final ProgressRepository _progressRepo;
  late final BookRepository _bookRepo;
  late final ChapterRepository _chapterRepo;
  late final SettingsRepository _settingsRepo;
  final TtsPlayer _player = TtsPlayer(DeviceTts());
  ReadingProgressController? _progressController;
  Timer? _progressTimer;
  StreamSubscription<TtsEvent>? _ttsSub;
  List<String> _sentences = [];
  List<double> _sentenceScales = [];
  List<bool> _sentenceIsBlockStart = [];
  bool _ttsInited = false;

  ReaderNotifier(this.bookId, this._ref) : super(const ReaderState(isLoading: true)) {
    _progressRepo = _ref.read(progressRepositoryProvider);
    _bookRepo = _ref.read(bookRepositoryProvider);
    _chapterRepo = _ref.read(chapterRepositoryProvider);
    _settingsRepo = _ref.read(settingsRepositoryProvider);
  }

  // ---------------------------------------------------------------------------
  // TTS lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _initTts() async {
    if (_ttsInited) return;
    final pitch = await _settingsRepo.getPitch();
    await _player.init(speed: state.speed, pitch: pitch);
    _ttsSub = _player.events.listen(_onTtsEvent);
    _ttsInited = true;
  }

  void _onTtsEvent(TtsEvent event) {
    if (event.type == TtsEventType.completed && state.isPlaying) {
      _advanceToNextSentence();
    }
  }

  void _advanceToNextSentence() {
    final nextIdx = state.currentSentenceIndex + 1;
    if (nextIdx < _sentences.length) {
      _player.speak(_sentences[nextIdx]);
      _syncProgress(nextIdx);
    } else {
      // Reached end of chapter
      _syncProgress(state.currentSentenceIndex);
      _saveProgressImmediately();
      _checkAutoNextChapter();
    }
  }

  void _checkAutoNextChapter() {
    if (!state.autoNextChapter ||
        state.currentChapterIndex >= state.chapters.length - 1) {
      state = state.copyWith(isPlaying: false, isPaused: false);
      return;
    }
    _performAutoNextChapter();
  }

  Future<void> _performAutoNextChapter() async {
    final nextIdx = state.currentChapterIndex + 1;
    await _loadChapter(nextIdx);
    if (_sentences.isNotEmpty) {
      _player.speak(_sentences[0]);
      state = state.copyWith(isPlaying: true, isPaused: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Sentence list management
  // ---------------------------------------------------------------------------

  void _parseSentencesFromBlocks(List<TextBlock> blocks) {
    _sentences = [];
    _sentenceScales = [];
    _sentenceIsBlockStart = [];
    for (final block in blocks) {
      final parts = block.text.split(RegExp(r'(?<=[。！？\n])'));
      for (int i = 0; i < parts.length; i++) {
        final s = parts[i].trim();
        if (s.isEmpty) continue;
        _sentences.add(s);
        _sentenceScales.add(block.scale);
        _sentenceIsBlockStart.add(i == 0);
      }
    }
  }

  int _charOffsetToSentenceIndex(int charOffset) {
    if (charOffset <= 0 || _sentences.isEmpty) return 0;
    var acc = 0;
    for (int i = 0; i < _sentences.length; i++) {
      acc += _sentences[i].length;
      if (acc > charOffset) return i;
    }
    return _sentences.length - 1;
  }

  int _computeCharOffset(int sentenceIndex) {
    var offset = 0;
    for (int i = 0; i < sentenceIndex && i < _sentences.length; i++) {
      offset += _sentences[i].length;
    }
    return offset;
  }

  void _syncProgress(int sentenceIndex) {
    final charOffset = _computeCharOffset(sentenceIndex);
    final totalProgress = _computeTotalProgress(state.currentChapterIndex, charOffset);
    _progressController?.advance(state.currentChapterIndex, charOffset, totalProgress);
    state = state.copyWith(
      currentSentenceIndex: sentenceIndex,
      charOffset: charOffset,
      totalProgress: totalProgress.clamp(0.0, 1.0),
    );
  }

  // ---------------------------------------------------------------------------
  // Book / chapter loading
  // ---------------------------------------------------------------------------

  Future<void> loadBook() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Restore persistent settings before TTS init
      final savedSpeed = await _settingsRepo.getSpeed();
      final autoNext = await _settingsRepo.getAutoNextChapter();
      state = state.copyWith(speed: savedSpeed, autoNextChapter: autoNext);

      await _initTts();

      final book = await _bookRepo.getById(bookId);
      if (book == null) {
        state = state.copyWith(isLoading: false, error: 'Book not found');
        return;
      }

      final chapters = await _chapterRepo.getByBookId(bookId);

      final savedProgress = await _progressRepo.load(bookId);
      final initialProgress = savedProgress ?? ReadingProgress(
        bookId: bookId,
        chapterIndex: 0,
        charOffset: 0,
        totalProgress: 0.0,
        lastReadAt: DateTime.now(),
      );

      _progressController = ReadingProgressController(
        repo: _progressRepo,
        initial: initialProgress,
      );

      final chapterIndex = initialProgress.chapterIndex;
      final charOffset = initialProgress.charOffset;

      List<TextBlock> blocks = [];
      if (chapters.isNotEmpty && chapterIndex < chapters.length) {
        blocks = await _parser.getChapterBlocks(book.filePath, chapterIndex);
      }

      _parseSentencesFromBlocks(blocks);
      final sentenceIndex = _charOffsetToSentenceIndex(charOffset);
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
        sentences: List.unmodifiable(_sentences),
        sentenceScales: List.unmodifiable(_sentenceScales),
        sentenceIsBlockStart: List.unmodifiable(_sentenceIsBlockStart),
        currentSentenceIndex: sentenceIndex,
        autoNextChapter: autoNext,
      );

      AppLogger.instance.info('Book loaded: ${book.title}, chapter ${chapterIndex + 1}/${chapters.length}, '
          'charOffset=$charOffset, sentenceIdx=$sentenceIndex, progressData=${savedProgress != null ? "found" : "none"}');
      _startProgressTimer();
    } catch (e) {
      AppLogger.instance.error('Book load failed', e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadChapter(int index) async {
    if (state.book == null) return;
    _player.stop();
    final blocks = await _parser.getChapterBlocks(state.book!.filePath, index);
    _parseSentencesFromBlocks(blocks);
    final totalProgress = state.chapters.isNotEmpty ? index / state.chapters.length : 0.0;
    state = state.copyWith(
      currentChapterIndex: index,
      charOffset: 0,
      currentContent: blocks.map((b) => b.text).join('\n'),
      currentBlocks: blocks,
      totalProgress: totalProgress,
      sentences: List.unmodifiable(_sentences),
      sentenceScales: List.unmodifiable(_sentenceScales),
      sentenceIsBlockStart: List.unmodifiable(_sentenceIsBlockStart),
      currentSentenceIndex: 0,
      isPlaying: false,
      isPaused: false,
    );
    await _progressController?.seekTo(index, 0, totalProgress);
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

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  void togglePlayPause() {
    if (_sentences.isEmpty) return;
    if (state.isPlaying) {
      _player.pause();
      state = state.copyWith(isPlaying: false, isPaused: true);
      _saveProgressImmediately();
    } else {
      _player.speak(_sentences[state.currentSentenceIndex]);
      state = state.copyWith(isPlaying: true, isPaused: false);
    }
  }

  void nextSentence() {
    if (_sentences.isEmpty || state.currentSentenceIndex >= _sentences.length - 1) return;
    final nextIdx = state.currentSentenceIndex + 1;
    _player.stop();
    _player.speak(_sentences[nextIdx]);
    _syncProgress(nextIdx);
  }

  void prevSentence() {
    if (_sentences.isEmpty || state.currentSentenceIndex <= 0) return;
    final prevIdx = state.currentSentenceIndex - 1;
    _player.stop();
    _player.speak(_sentences[prevIdx]);
    _syncProgress(prevIdx);
  }

  void seekToSentence(int index) {
    if (_sentences.isEmpty || index < 0 || index >= _sentences.length) return;
    _player.stop();
    state = state.copyWith(isPlaying: false, isPaused: false);
    _syncProgress(index);
  }

  void pause() {
    if (!state.isPlaying) return;
    _player.pause();
    state = state.copyWith(isPlaying: false, isPaused: true);
    _saveProgressImmediately();
  }

  Future<void> updateTtsSettings(double speed, double pitch) async {
    await Future.wait([
      _player.setSpeed(speed),
      _player.setPitch(pitch),
      _settingsRepo.setSpeed(speed),
      _settingsRepo.setPitch(pitch),
    ]);
    state = state.copyWith(speed: speed);
    if (state.isPlaying) {
      _player.speak(_sentences[state.currentSentenceIndex]);
    }
  }

  Future<void> setAutoNextChapter(bool value) async {
    await _settingsRepo.setAutoNextChapter(value);
    state = state.copyWith(autoNextChapter: value);
  }

  /// Persist current reading position immediately.
  Future<void> persistProgress() async {
    if (state.book == null || _progressController == null) return;
    final charOffset = _computeCharOffset(state.currentSentenceIndex);
    final totalProgress = _computeTotalProgress(state.currentChapterIndex, charOffset);
    _progressController?.advance(state.currentChapterIndex, charOffset, totalProgress);
    await _saveProgressImmediately();
  }

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

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
    _ttsSub?.cancel();
    _player.stop();
    _progressController?.dispose();
    _player.dispose();
    super.dispose();
  }
}
