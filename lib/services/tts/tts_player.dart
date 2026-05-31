import 'dart:async';
import 'tts_base.dart';

/// Playback state emitted by [TtsPlayer].
class TtsPlaybackState {
  final int currentIndex;
  final bool isPlaying;
  final bool isPaused;
  final bool isCompleted;
  final bool hasNext;
  final bool hasPrevious;
  final String? error;

  const TtsPlaybackState({
    required this.currentIndex,
    this.isPlaying = false,
    this.isPaused = false,
    this.isCompleted = false,
    this.hasNext = false,
    this.hasPrevious = false,
    this.error,
  });
}

/// Manages TTS playback of a sentence queue, independent of any UI page.
///
/// Owns the [TtsEngine] instance, auto-advances on sentence completion,
/// and emits state changes on [state$]. UI pages subscribe to [state$]
/// and call methods to control playback.
class TtsPlayer {
  final TtsEngine _engine;
  final StreamController<TtsPlaybackState> _stateController =
      StreamController<TtsPlaybackState>.broadcast();

  List<String> _sentences = [];
  int _currentIndex = 0;
  int get sentenceCount => _sentences.length;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _initialized = false;
  String? _initError;
  StreamSubscription<TtsEvent>? _engineSub;

  TtsPlayer(this._engine);

  /// Stream of playback state changes.
  Stream<TtsPlaybackState> get state$ => _stateController.stream;

  /// Current snapshot.
  TtsPlaybackState get current => _buildState();

  /// Initialize the TTS engine. Call once before first [play].
  Future<void> init({double speed = 1.0, double pitch = 1.0}) async {
    if (_initialized) return;
    try {
      await _engine.init();
      await _engine.setSpeed(speed);
      await _engine.setPitch(pitch);
      _engineSub = _engine.events.listen(_onEngineEvent);
      _initialized = true;
    } catch (e) {
      _initError = e.toString();
      _emit();
    }
  }

  /// Load a new sentence queue without starting playback.
  void loadSentences(List<String> sentences, {int startIndex = 0}) {
    _sentences = List.from(sentences);
    _currentIndex = startIndex.clamp(0, _sentences.length - 1);
    _isCompleted = false;
    _emit();
  }

  /// Start or resume playback from the current position.
  Future<void> play() async {
    if (!_initialized && _initError == null) {
      await init();
    }
    if (_initError != null) return;
    if (_sentences.isEmpty) return;

    // Completed — restart from beginning.
    if (_isCompleted) {
      _currentIndex = 0;
      _isCompleted = false;
    }

    // Guard: if engine reports it's already speaking (e.g. resume path),
    // don't re-speak.
    if (_isPlaying && !_isPaused) return;

    _isPlaying = true;
    _isPaused = false;
    _emit();
    await _engine.speak(_sentences[_currentIndex]);
  }

  /// Pause playback. TTS engine stops; position is preserved.
  Future<void> pause() async {
    if (!_isPlaying) return;
    await _engine.stop();
    _isPlaying = false;
    _isPaused = true;
    _emit();
  }

  /// Stop playback and reset position to 0.
  Future<void> stop() async {
    await _engine.stop();
    _isPlaying = false;
    _isPaused = false;
    _isCompleted = false;
    _currentIndex = 0;
    _emit();
  }

  /// Advance to next sentence.
  Future<void> next() async {
    if (_currentIndex >= _sentences.length - 1) return;
    await _engine.stop();
    _currentIndex++;
    _isCompleted = false;
    if (_isPlaying) {
      await _engine.speak(_sentences[_currentIndex]);
    }
    _emit();
  }

  /// Go to previous sentence.
  Future<void> previous() async {
    if (_currentIndex <= 0) return;
    await _engine.stop();
    _currentIndex--;
    _isCompleted = false;
    if (_isPlaying) {
      await _engine.speak(_sentences[_currentIndex]);
    }
    _emit();
  }

  /// Jump to a specific sentence index without starting playback.
  /// Call before [play] to change position.
  Future<void> seekTo(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    await _engine.stop();
    _currentIndex = index;
    _isCompleted = false;
    if (_isPlaying) {
      await _engine.speak(_sentences[_currentIndex]);
    }
    _emit();
  }

  Future<void> setSpeed(double speed) async {
    await _engine.setSpeed(speed);
  }

  Future<void> setPitch(double pitch) async {
    await _engine.setPitch(pitch);
  }

  void _onEngineEvent(TtsEvent event) {
    switch (event.type) {
      case TtsEventType.completed:
        // Only auto-advance if we're still playing (ignore stale events
        // from interrupted utterances after stop/pause).
        if (_isPlaying) {
          _onSentenceComplete();
        }
      case TtsEventType.error:
        _emit();
      default:
        break;
    }
  }

  void _onSentenceComplete() {
    if (_currentIndex < _sentences.length - 1) {
      _currentIndex++;
      _emit();
      // Auto-advance to next sentence.
      _engine.speak(_sentences[_currentIndex]);
    } else {
      _isPlaying = false;
      _isCompleted = true;
      _emit();
    }
  }

  TtsPlaybackState _buildState() {
    return TtsPlaybackState(
      currentIndex: _currentIndex,
      isPlaying: _isPlaying,
      isPaused: _isPaused,
      isCompleted: _isCompleted,
      hasNext: _currentIndex < _sentences.length - 1,
      hasPrevious: _currentIndex > 0,
      error: _initError,
    );
  }

  void _emit() {
    if (!_stateController.isClosed) {
      _stateController.add(_buildState());
    }
  }

  Future<void> dispose() async {
    await _engineSub?.cancel();
    await _engine.stop();
    await _engine.dispose();
    await _stateController.close();
  }
}
