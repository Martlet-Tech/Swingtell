import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_base.dart';

class DeviceTts implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  final StreamController<TtsEvent> _eventController = StreamController<TtsEvent>.broadcast();
  bool _isPlaying = false;
  bool _isPaused = false;

  @override
  Future<void> init() async {
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.5); // FlutterTTS range: 0.0-1.0
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _isPlaying = true;
      _isPaused = false;
    });

    _tts.setCompletionHandler(() {
      _isPlaying = false;
      _isPaused = false;
      _eventController.add(TtsEvent(type: TtsEventType.completed));
    });

    _tts.setErrorHandler((msg) {
      _isPlaying = false;
      _isPaused = false;
      _eventController.add(TtsEvent(type: TtsEventType.error, error: msg));
    });

    _tts.setProgressHandler((String text, int start, int end, String word) {
      _eventController.add(TtsEvent(
        type: TtsEventType.progress,
        word: word,
        start: start,
        end: end,
      ));
    });
  }

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> pause() async {
    await _tts.pause();
    _isPaused = true;
  }

  @override
  Future<void> resume() async {
    // flutter_tts on some platforms doesn't support resume;
    // stop and re-speak the current text is handled at higher level
    _isPaused = false;
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
    _isPaused = false;
  }

  @override
  Future<void> setSpeed(double speed) async {
    // speed is 0.5-3.0 (user-facing), flutter_tts uses 0.0-1.0
    // Map: 0.5x -> ~0.2, 1.0x -> 0.5, 2.0x -> 0.75, 3.0x -> 1.0
    final ttsRate = (speed / 3.0).clamp(0.0, 1.0);
    await _tts.setSpeechRate(ttsRate);
  }

  @override
  Future<void> setVoice(String voiceId) async {
    // FlutterTTS uses setLanguage for voice selection
    await _tts.setLanguage(voiceId);
  }

  @override
  Stream<TtsEvent> get events => _eventController.stream;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> dispose() async {
    await _tts.stop();
    await _eventController.close();
  }
}
