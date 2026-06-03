import 'package:flutter/foundation.dart';
import '../../core/models/book.dart';
import '../../core/models/reading_progress.dart';
import '../../core/models/reader_settings.dart';
import '../../core/services/epub_service.dart';
import '../../core/services/progress_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/tts/tts_pipeline.dart';

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
  double get initialScrollOffset => _progress.scrollOffset;
  bool get isLoading => _loading;
  ReadingProgress get progress => _progress;
  ReaderSettings get settings => _settingsService.settings;
  bool get isTtsPlaying => _ttsState.isPlaying;
  TtsState get ttsState => _ttsState;

  Future<void> init() async {
    try {
      _chapters = await _epubService.extractChapters(_book.filePath);
      _chapterTexts = await _epubService.extractChapterTexts(_book.filePath);
      _chapterTitles = await _epubService.extractChapterTitles(_book.filePath);

      _progress = _progressService.getProgress(_book.id);
      _currentChapterIndex = _progress.chapterIndex;
      _currentHtml = _chapters.isNotEmpty ? _chapters[_currentChapterIndex] : null;

      _settingsService.addListener(_onSettingsChanged);
      _ttsPipeline.stateStream.listen(_onTtsStateChanged);
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
    notifyListeners();
  }

  void onScroll(double scrollY, double pageHeight) {
    _progress.scrollOffset = scrollY;
    _progress.percentage = (_currentChapterIndex / _chapters.length) +
        (scrollY / pageHeight) * (1 / _chapters.length);
    _progressService.saveProgress(_progress);
  }

  void goToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    _progressService.saveProgress(_progress);
    _progress.chapterIndex = index;
    _progress.scrollOffset = 0.0;
    _currentChapterIndex = index;
    _currentHtml = _chapters[index];
    notifyListeners();
  }

  Future<void> toggleTts() async {
    if (_ttsState.isPlaying) {
      await _ttsPipeline.pause();
    } else {
      if (_ttsState.paragraphIndex > 0) {
        await _ttsPipeline.resume();
      } else {
        await _ttsPipeline.start(
          chapterTexts: _chapterTexts,
          chapterIndex: _currentChapterIndex,
        );
      }
    }
  }

  Future<void> stopTts() async {
    await _ttsPipeline.stop();
  }

  void onAppPause() {
    _progressService.saveProgress(_progress);
  }

  @override
  void dispose() {
    _settingsService.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
