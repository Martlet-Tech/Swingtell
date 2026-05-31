import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'native_tts.dart';
import 'tts_base.dart';

class DeviceTts implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  TtsEngine? _fallback; // NativeTts when flutter_tts fails on newer Android
  StreamSubscription<TtsEvent>? _fallbackSub;
  final StreamController<TtsEvent> _eventController =
      StreamController<TtsEvent>.broadcast();
  bool _isPlaying = false;
  bool _isPaused = false;

  @override
  Future<void> init() async {
    await _tts.setLanguage('zh-CN');
    // Give the native listener a moment to fire
    await Future.delayed(const Duration(milliseconds: 300));

    final dynamic engines = await _tts.getEngines;
    final engineList =
        (engines is List ? engines.cast<String>() : <String>[]);

    if (engineList.isNotEmpty) {
      // flutter_tts works on this device — use it
      await _tts.setSpeechRate(0.5);
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
    } else {
      // flutter_tts can't detect engines — try native fallback
      final nativeEngines = await NativeTts.getInstalledEngines();
      if (nativeEngines.isEmpty) {
        throw Exception(
          '没有可用的 TTS 引擎。请在手机 设置 → 文字转语音(TTS) 中检查。',
        );
      }
      final native = NativeTts();
      await native.init();
      _fallback = native;
      _fallbackSub = native.events.listen((event) {
        switch (event.type) {
          case TtsEventType.completed:
          case TtsEventType.error:
            _isPlaying = false;
            _isPaused = false;
            break;
          case TtsEventType.progress:
            _isPlaying = true;
            _isPaused = false;
            break;
          case TtsEventType.word:
            break;
        }
        _eventController.add(event);
      });
    }
  }

  @override
  Future<void> speak(String text) async {
    if (_fallback != null) {
      await _fallback!.speak(text);
    } else {
      await _tts.speak(text);
    }
  }

  @override
  Future<void> pause() async {
    if (_fallback != null) {
      await _fallback!.pause();
    } else {
      await _tts.pause();
    }
    _isPaused = true;
  }

  @override
  Future<void> resume() async {
    // No-op — higher level handles re-speak
    _isPaused = false;
  }

  @override
  Future<void> stop() async {
    if (_fallback != null) {
      await _fallback!.stop();
    } else {
      await _tts.stop();
    }
    _isPlaying = false;
    _isPaused = false;
  }

  @override
  Future<void> setSpeed(double speed) async {
    // speed is 0.5-3.0 (user-facing), flutter_tts uses 0.0-1.0
    final ttsRate = (speed / 3.0).clamp(0.0, 1.0);
    if (_fallback != null) {
      await _fallback!.setSpeed(speed);
    } else {
      await _tts.setSpeechRate(ttsRate);
    }
  }

  @override
  Future<void> setPitch(double pitch) async {
    if (_fallback != null) {
      await _fallback!.setPitch(pitch);
    } else {
      await _tts.setPitch(pitch);
    }
  }

  @override
  Future<void> setVoice(String voiceId) async {
    if (_fallback != null) {
      await _fallback!.setVoice(voiceId);
    } else {
      await _tts.setLanguage(voiceId);
    }
  }

  @override
  Stream<TtsEvent> get events => _eventController.stream;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> openSystemSettings() async {
    if (_fallback != null) {
      await _fallback!.openSystemSettings();
    } else {
      await const MethodChannel('swingtell_tts').invokeMethod('openTtsSettings');
    }
  }

  @override
  Future<void> dispose() async {
    await _fallbackSub?.cancel();
    if (_fallback != null) {
      await _fallback!.dispose();
    } else {
      await _tts.stop();
    }
    await _eventController.close();
  }
}
