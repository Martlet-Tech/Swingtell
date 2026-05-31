import 'dart:async';
import 'tts_base.dart';

/// Thin wrapper around [TtsEngine].
///
/// Owns the engine instance and exposes only the operations needed to
/// drive playback. All coordination logic lives in [ReaderNotifier].
class TtsPlayer {
  final TtsEngine _engine;
  bool _initialized = false;
  StreamSubscription<TtsEvent>? _engineSub;
  final StreamController<TtsEvent> _eventController =
      StreamController<TtsEvent>.broadcast();

  TtsPlayer(this._engine);

  Stream<TtsEvent> get events => _eventController.stream;

  Future<void> init({double speed = 1.0, double pitch = 1.0}) async {
    if (_initialized) return;
    await _engine.init();
    await _engine.setSpeed(speed);
    await _engine.setPitch(pitch);
    _engineSub = _engine.events.listen((event) {
      _eventController.add(event);
    });
    _initialized = true;
  }

  Future<void> speak(String text) => _engine.speak(text);
  Future<void> pause() => _engine.pause();
  Future<void> stop() => _engine.stop();
  Future<void> setSpeed(double speed) => _engine.setSpeed(speed);
  Future<void> setPitch(double pitch) => _engine.setPitch(pitch);

  Future<void> dispose() async {
    _engineSub?.cancel();
    await _engine.stop();
    await _engine.dispose();
    await _eventController.close();
  }
}
