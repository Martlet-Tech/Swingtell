import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/models/book.dart';
import '../../core/models/reading_progress.dart';
import '../../core/models/reader_settings.dart';
import '../../core/services/epub_service.dart';
import '../../core/services/progress_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/tts/tts_pipeline.dart';

enum TtsScrollState { idle, playing, userScrolled }

class ReaderViewModel extends ChangeNotifier {
  final EpubService _epubService;
  final ProgressService _progressService;
  final SettingsService _settingsService;
  final TtsPipeline _ttsPipeline;
  final Book _book;

  List<String> _chapters = [];
  List<String> _chapterTexts = [];
  List<String> _chapterTitles = [];
  ReadingProgress _progress = ReadingProgress();
  int _currentChapterIndex = 0;
  String? _currentHtml;
  bool _loading = true;
  TtsState _ttsState = TtsState.idle;

  // 状态机
  TtsScrollState _scrollState = TtsScrollState.idle;
  DateTime _lastProgrammaticScroll = DateTime(0);
  String _lastTtsUnitText = '';
  String _lastUserScrollText = '';

  // 浮动按钮
  bool showFloatButtons = false;
  Timer? _floatButtonTimer;

  StreamSubscription<TtsState>? _ttsStateSub;

  // 由 ReaderScreen 注入的回调
  void Function(String text)? onRestoreScroll;
  void Function(TtsState state)? onTtsStateChanged;

  static const _programmaticScrollCooldown = Duration(milliseconds: 1500);

  ReaderViewModel({
    required EpubService epubService,
    required ProgressService progressService,
    required SettingsService settingsService,
    required TtsPipeline ttsPipeline,
    required Book book,
  })  : _epubService = epubService,
        _progressService = progressService,
        _settingsService = settingsService,
        _ttsPipeline = ttsPipeline,
        _book = book;

  Book get book => _book;
  List<String> get chapters => _chapters;
  List<String> get chapterTitles => _chapterTitles;
  String? get currentHtml => _currentHtml;
  int get currentChapterIndex => _currentChapterIndex;
  bool get isLoading => _loading;
  ReadingProgress get progress => _progress;
  ReaderSettings get settings => _settingsService.settings;
  bool get isTtsPlaying => _ttsState.isPlaying;
  TtsState get ttsState => _ttsState;
  TtsScrollState get scrollState => _scrollState;
  String get lastTtsUnitText => _lastTtsUnitText;
  String get lastUserScrollText => _lastUserScrollText;

  String get _plainText {
    if (_currentChapterIndex >= _chapterTexts.length) return '';
    return _chapterTexts[_currentChapterIndex];
  }

  List<String> get _currentParagraphs {
    final text = _plainText;
    if (text.isEmpty) return [];
    return text
        .split(RegExp(r'\n{1,}'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> init() async {
    try {
      _chapters = await _epubService.extractChapters(_book.filePath);
      _chapterTexts = await _epubService.extractChapterTexts(_book.filePath);
      _chapterTitles = await _epubService.extractChapterTitles(_book.filePath);

      _progress = _progressService.getProgress(_book.id);
      _currentChapterIndex = _progress.chapterIndex;
      _currentHtml = _chapters.isNotEmpty ? _chapters[_currentChapterIndex] : null;

      _settingsService.addListener(_onSettingsChanged);
      _ttsStateSub = _ttsPipeline.stateStream.listen(_onTtsStateChanged);
    } catch (e) {
      debugPrint('[ReaderVM] init error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _onSettingsChanged() {
    notifyListeners();
  }

  void _onTtsStateChanged(TtsState state) {
    _ttsState = state;
    if (state.isPlaying && state.currentUnitText.isNotEmpty) {
      _lastTtsUnitText = state.currentUnitText;
    }
    onTtsStateChanged?.call(state);
    if (state.chapterIndex != _currentChapterIndex && state.isPlaying) {
      goToChapter(state.chapterIndex);
    }
    notifyListeners();
  }

  void onScrollSettled(String visibleText) {
    if (visibleText.isEmpty) return;

    final elapsed = DateTime.now().difference(_lastProgrammaticScroll);
    if (elapsed < _programmaticScrollCooldown) return;

    if (_scrollState == TtsScrollState.playing) {
      _scrollState = TtsScrollState.userScrolled;
    }

    _lastUserScrollText = visibleText;

    final offset = _findCharOffset(visibleText);
    if (offset >= 0) {
      _progress.charOffset = offset;
      _progress.percentage = _calcPercentage();
      _progressService.saveProgress(_progress);
    }

    showFloatButtons = false;
    notifyListeners();
    _floatButtonTimer?.cancel();
    _floatButtonTimer = Timer(const Duration(seconds: 1), () {
      if (_ttsState.isPlaying) {
        showFloatButtons = true;
        notifyListeners();
      }
    });
  }

  void onPageReady() {
    if (_progress.charOffset > 0) {
      final text = _textAtOffset(_progress.charOffset);
      onRestoreScroll?.call(text);
    }
  }

  double _calcPercentage() {
    final text = _plainText;
    if (text.isEmpty) return 0;
    return (_currentChapterIndex / _chapters.length) +
        (_progress.charOffset / text.length) * (1 / _chapters.length);
  }

  int _findCharOffset(String visibleText) {
    final text = _plainText;
    if (visibleText.isEmpty || text.isEmpty) return -1;
    final anchor = visibleText.substring(0, min(20, visibleText.length));
    return text.indexOf(anchor);
  }

  String _textAtOffset(int charOffset) {
    final text = _plainText;
    if (charOffset >= text.length) return '';
    final end = _findNextSentenceEnd(text, charOffset);
    return text.substring(charOffset, end);
  }

  int _findNextSentenceEnd(String text, int start) {
    const ends = ['。', '！', '？', '\n', '.', '!', '?'];
    int earliest = text.length;
    for (final e in ends) {
      final idx = text.indexOf(e, start);
      if (idx != -1 && idx < earliest) earliest = idx + 1;
    }
    return earliest < text.length ? earliest : text.length;
  }

  int _findParagraphAtOffset(int charOffset) {
    final text = _plainText;
    int count = 0;
    for (int i = 0; i < text.length;) {
      while (i < text.length && text[i] == '\n') { i++; }
      if (i >= text.length) break;
      final end = text.indexOf('\n', i);
      final paraEnd = end == -1 ? text.length : end;
      if (text.substring(i, paraEnd).trim().isNotEmpty) {
        if (charOffset >= i && charOffset < paraEnd) return count;
        count++;
      }
      i = end == -1 ? text.length : end + 1;
    }
    return 0;
  }

  void goToChapter(int index, {bool userInitiated = false}) {
    if (index < 0 || index >= _chapters.length) return;
    if (userInitiated) {
      _progressService.saveProgress(_progress);
      _ttsPipeline.stop();
      _scrollState = TtsScrollState.idle;
    }
    _progress.chapterIndex = index;
    _progress.charOffset = 0;
    _currentChapterIndex = index;
    _currentHtml = _chapters[index];
    notifyListeners();
  }

  Future<void> toggleTts() async {
    if (_ttsState.isPlaying) {
      await _ttsPipeline.pause();
      _scrollState = TtsScrollState.idle;
    } else if (_ttsState.paragraphIndex > 0) {
      _scrollState = TtsScrollState.playing;
      await _ttsPipeline.resume();
    }
  }

  Future<void> startTtsAt(String visibleText) async {
    _scrollState = TtsScrollState.playing;
    int paraOffset = 0;
    if (visibleText.isNotEmpty) {
      final offset = _findCharOffset(visibleText);
      if (offset >= 0) {
        paraOffset = _findParagraphAtOffset(offset);
      }
    }
    if (paraOffset == 0 && _progress.charOffset > 0) {
      paraOffset = _findParagraphAtOffset(_progress.charOffset);
    }
    final chapterTitle = _currentChapterIndex < _chapterTitles.length
        ? _chapterTitles[_currentChapterIndex]
        : '';
    final ctx = '《${_book.title}》${chapterTitle.isNotEmpty ? " $chapterTitle" : ""}';
    await _ttsPipeline.start(
      chapterTexts: _chapterTexts,
      chapterIndex: _currentChapterIndex,
      paragraphOffset: paraOffset,
      chapterContext: ctx,
    );
  }

  Future<void> stopTts() async {
    await _ttsPipeline.stop();
    _scrollState = TtsScrollState.idle;
  }

  void markProgrammaticScroll() {
    _lastProgrammaticScroll = DateTime.now();
  }

  void returnToTtsUnit() {
    if (_scrollState == TtsScrollState.userScrolled) {
      _scrollState = TtsScrollState.playing;
    }
    showFloatButtons = false;
    notifyListeners();
  }

  void startTtsHere() {
    if (_scrollState == TtsScrollState.userScrolled) {
      _scrollState = TtsScrollState.playing;
    }
    showFloatButtons = false;
    notifyListeners();
  }

  void hideFloatButtons() {
    showFloatButtons = false;
    notifyListeners();
  }

  Future<void> seekTtsToVisibleText(String visibleText) async {
    final offset = _findCharOffset(visibleText);
    if (offset < 0) return;

    final text = _plainText;
    int unitIndex = 0;
    for (int i = 0; i < text.length;) {
      while (i < text.length && text[i] == '\n') { i++; }
      if (i >= text.length) break;
      final end = text.indexOf('\n', i);
      final paraEnd = end == -1 ? text.length : end;
      if (text.substring(i, paraEnd).trim().isNotEmpty) {
        if (offset >= i && offset < paraEnd) break;
        unitIndex++;
      }
      i = end == -1 ? text.length : end + 1;
    }

    final paragraphs = _currentParagraphs;
    if (unitIndex >= paragraphs.length) unitIndex = paragraphs.length - 1;

    await _ttsPipeline.start(
      chapterTexts: _chapterTexts,
      chapterIndex: _currentChapterIndex,
      paragraphOffset: unitIndex,
    );
  }

  void onAppPause() {
    _progressService.saveProgress(_progress);
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    _floatButtonTimer?.cancel();
    _ttsStateSub?.cancel();
    super.dispose();
  }
}
