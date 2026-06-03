import 'dart:async';
import 'package:flutter/services.dart';

class NativeTts {
  static const _channel = MethodChannel('swingtell_tts');
  final StreamController<TtsEvent> _eventController =
      StreamController<TtsEvent>.broadcast();
  bool _initialized = false;

  Stream<TtsEvent> get events => _eventController.stream;
  bool get isInitialized => _initialized;

  static Future<List<String>> getInstalledEngines() async {
    try {
      final result = await _channel.invokeMethod('getInstalledEngines');
      return (result as List?)?.cast<String>() ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> init({String? engine}) async {
    try {
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onStart':
            break;
          case 'onDone':
            _eventController.add(TtsEvent(type: TtsEventType.completed));
            break;
          case 'onError':
            _eventController.add(TtsEvent(
              type: TtsEventType.error,
              error: call.arguments as String?,
            ));
            break;
        }
      });

      final args = <String, dynamic>{};
      if (engine != null) args['engine'] = engine;
      final result = await _channel.invokeMethod('init', args);
      final map = Map<String, dynamic>.from(result as Map);
      _initialized = map['success'] == true;

      return _initialized;
    } catch (e) {
      _initialized = false;
      return false;
    }
  }

  Future<bool> tryAllEngines() async {
    // Try default first
    if (await init()) return true;

    final engines = await getInstalledEngines();
    for (final engine in engines) {
      if (await init(engine: engine)) return true;
    }
    return false;
  }

  Future<void> speak(String text) async {
    if (!_initialized) return;
    await _channel.invokeMethod('speak', <String, dynamic>{'text': text});
  }

  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  Future<void> setSpeechRate(double rate) async {
    await _channel.invokeMethod('setSpeechRate', <String, dynamic>{'rate': rate});
  }

  Future<void> setPitch(double pitch) async {
    await _channel.invokeMethod('setPitch', <String, dynamic>{'pitch': pitch});
  }

  Future<void> setLanguage(String language) async {
    await _channel.invokeMethod('setLanguage', <String, dynamic>{'language': language});
  }

  Future<void> openSystemSettings() async {
    await _channel.invokeMethod('openTtsSettings');
  }

  void dispose() {
    _eventController.close();
  }
}

enum TtsEventType { progress, completed, error, word }

class TtsEvent {
  final TtsEventType type;
  final String? word;
  final int? start;
  final int? end;
  final String? error;

  TtsEvent({required this.type, this.word, this.start, this.end, this.error});
}
