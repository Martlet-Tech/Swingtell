import 'dart:async';
import 'package:flutter/services.dart';
import 'tts_base.dart';

/// Native TTS engine using a custom MethodChannel (bypasses flutter_tts).
///
/// Used as a fallback when flutter_tts cannot bind on newer Android versions.
class NativeTts implements TtsEngine {
  static const _channel = MethodChannel('swingtell_tts');
  final StreamController<TtsEvent> _eventController =
      StreamController<TtsEvent>.broadcast();
  bool _isPlaying = false;
  bool _isPaused = false;

  /// Query installed TTS engines via the static API (works on Android 14+).
  static Future<List<String>> getInstalledEngines() async {
    try {
      final result = await _channel.invokeMethod('getInstalledEngines');
      return (result as List?)?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> init() async {
    // Listen to native callbacks
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onStart':
          _isPlaying = true;
          _isPaused = false;
        case 'onDone':
          _isPlaying = false;
          _isPaused = false;
          _eventController.add(TtsEvent(type: TtsEventType.completed));
        case 'onError':
          _isPlaying = false;
          _isPaused = false;
          _eventController
              .add(TtsEvent(type: TtsEventType.error, error: call.arguments as String?));
      }
    });

    // Try default engine first
    var result = await _channel.invokeMethod('init', <String, dynamic>{});
    var map = Map<String, dynamic>.from(result as Map);
    if (map['success'] == true) return;

    // Default failed — try each installed engine
    final engines = await getInstalledEngines();
    for (final engine in engines) {
      result = await _channel.invokeMethod('init', <String, dynamic>{'engine': engine});
      map = Map<String, dynamic>.from(result as Map);
      if (map['success'] == true) return;
    }

    throw Exception(
      'TTS 初始化失败：所有语音引擎都无法连接。请检查系统设置。',
    );
  }

  @override
  Future<void> speak(String text) async {
    await _channel.invokeMethod('speak', <String, dynamic>{'text': text});
  }

  @override
  Future<void> pause() async {
    await _channel.invokeMethod('stop');
    _isPaused = true;
  }

  @override
  Future<void> resume() async {
    // No-op — higher level handles re-speak
    _isPaused = false;
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
    _isPlaying = false;
    _isPaused = false;
  }

  @override
  Future<void> setSpeed(double speed) async {
    final rate = (speed / 3.0).clamp(0.0, 1.0);
    await _channel.invokeMethod('setSpeechRate', <String, dynamic>{'rate': rate});
  }

  @override
  Future<void> setVoice(String voiceId) async {
    await _channel.invokeMethod('setLanguage', <String, dynamic>{'language': voiceId});
  }

  @override
  Stream<TtsEvent> get events => _eventController.stream;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> dispose() async {
    await stop();
    await _eventController.close();
  }
}
