import 'dart:async';
import '../../models/reading_progress.dart';
import '../services/storage/progress_repository.dart';

/// Single owner of reading progress state.
///
/// All charOffset writes flow through this controller. TTS engine and UI
/// call methods here instead of mutating state directly. Consumers observe
/// progress changes via [stream] and never write to it.
class ReadingProgressController {
  final ProgressRepository _repo;
  final StreamController<ReadingProgress> _streamController =
      StreamController<ReadingProgress>.broadcast();
  ReadingProgress _current;

  ReadingProgressController({
    required ProgressRepository repo,
    required ReadingProgress initial,
  })  : _repo = repo,
        _current = initial;

  /// Broadcast stream of [ReadingProgress] — UI subscribes here.
  Stream<ReadingProgress> get stream => _streamController.stream;

  /// Current snapshot (no stream listen needed for one-shot reads).
  ReadingProgress get current => _current;

  /// Advance offset in memory only (high-frequency TTS callbacks).
  ///
  /// Does NOT persist — caller schedules persistence separately via [persist].
  void advance(int chapterIndex, int charOffset, double totalProgress) {
    _current = _current.copyWith(
      chapterIndex: chapterIndex,
      charOffset: charOffset,
      totalProgress: totalProgress,
    );
    _streamController.add(_current);
  }

  /// Persist current progress to database.
  Future<void> persist() async {
    _current = _current.copyWith(lastReadAt: DateTime.now());
    await _repo.save(_current);
  }

  /// Seek to a position and persist immediately (user drag, chapter switch).
  Future<void> seekTo(int chapterIndex, int charOffset, double totalProgress) async {
    _current = _current.copyWith(
      chapterIndex: chapterIndex,
      charOffset: charOffset,
      totalProgress: totalProgress,
      lastReadAt: DateTime.now(),
    );
    _streamController.add(_current);
    await _repo.save(_current);
  }

  /// Final save on dispose/exit, then close stream.
  Future<void> dispose() async {
    _current = _current.copyWith(lastReadAt: DateTime.now());
    await _repo.save(_current);
    await _streamController.close();
  }
}
