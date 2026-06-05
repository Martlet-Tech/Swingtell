import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_text_corrector.dart';
import 'tts_pipeline.dart';
import 'native_tts.dart';

class TtsPipelineImpl implements TtsPipeline {
  final TtsTextCorrector _corrector;
  FlutterTts? _tts;
  NativeTts? _nativeTts;
  bool _useNative = false;
  final _stateController = StreamController<TtsState>.broadcast();

  List<String> _allChapters = [];
  List<String> _currentParagraphs = [];
  int _chapterIndex = 0;
  int _paragraphIndex = 0;
  bool _playing = false;
  bool _disposed = false;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;
  

  TtsPipelineImpl({TtsTextCorrector? corrector})
      : _corrector = corrector ?? PassthroughCorrector();

  @override
  bool get isPlaying => _playing;

  @override
  Stream<TtsState> get stateStream => _stateController.stream;

  @override
  Future<void> init() async {
    // 策略：先检查 flutter_tts 是否能发现引擎（参考 DeviceTts）
    final tts = FlutterTts();
    dynamic engines;
    try {
      engines = await tts.getEngines;
    } catch (_) {
      engines = null;
    }

    final engineList = (engines is List ? engines.cast<String>() : <String>[]);
    if (engineList.isNotEmpty) {
      // flutter_tts 可用
      _tts = tts;
      await _useFlutterTts();
      debugPrint('[TTS] 使用 flutter_tts 引擎');
      return;
    }

    // flutter_tts 失败 → 原生 TTS
    tts.stop();
    debugPrint('[TTS] flutter_tts 不可用，尝试原生 TTS');
    final native = NativeTts();
    final ok = await native.tryAllEngines();
    if (ok) {
      _nativeTts = native;
      _useNative = true;
      _nativeTts!.events.listen((event) {
        if (event.type == TtsEventType.completed) {
          if (!_playing || _disposed) return;
          _speakNext();
        }
        if (event.type == TtsEventType.error) {
          debugPrint('[TTS] 原生引擎错误: ${event.error}');
          _playing = false;
          _emitState();
        }
      });
      debugPrint('[TTS] 使用原生 TTS 引擎');
      return;
    }

    debugPrint('[TTS] 错误：无可用的 TTS 引擎。请在手机设置中安装 TTS 语音引擎。');
  }

  Future<void> _useFlutterTts() async {
    final tts = _tts!;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await tts.setSharedInstance(true);
      await tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }

    await tts.setLanguage('zh-CN');
    await tts.setSpeechRate(0.5);
    await tts.setPitch(1.0);

    tts.setCompletionHandler(() {
      if (!_playing || _disposed) return;
      _speakNext();
    });
    tts.setErrorHandler((msg) {
      debugPrint('[TTS] flutter_tts 错误: $msg');
      _playing = false;
      _emitState();
    });
  }

  // ── 内部路由 ────────────────────────────────────────

  Future<void> _ttsStop() async {
    if (_useNative) {
      await _nativeTts?.stop();
    } else {
      await _tts?.stop();
    }
  }

  Future<void> _ttsSpeak(String text) async {
    if (_useNative) {
      await _nativeTts?.speak(text);
    } else {
      await _tts?.speak(text);
    }
  }

  Future<void> _ttsPause() async {
    if (_useNative) {
      await _nativeTts?.stop();
    } else {
      await _tts?.pause();
    }
  }

  Future<void> _ttsSetRate(double rate) async {
    if (_useNative) {
      await _nativeTts?.setSpeechRate(rate);
    } else {
      await _tts?.setSpeechRate(rate);
    }
  }

  Future<void> _ttsSetPitch(double pitch) async {
    if (_useNative) {
      await _nativeTts?.setPitch(pitch);
    } else {
      await _tts?.setPitch(pitch);
    }
  }

  // ── TtsPipeline 接口方法 ────────────────────────────

  @override
  Future<void> start({
    required List<String> chapterTexts,
    required int chapterIndex,
    int paragraphOffset = 0,
  }) async {
    await _ttsStop();
    _allChapters = chapterTexts;
    _chapterIndex = chapterIndex;
    _currentParagraphs = _splitParagraphs(chapterTexts[chapterIndex]);
    _paragraphIndex = paragraphOffset;
    _consecutiveErrors = 0;
    _playing = true;
    _emitState();
    await _speakCurrent();
  }

  @override
  Future<void> pause() async {
    if (!_playing) return;
    _playing = false;
    await _ttsPause();
    _emitState();
  }

  @override
  Future<void> resume() async {
    if (_playing) return;
    _playing = true;
    _emitState();
    await _speakCurrent();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _paragraphIndex = 0;
    _consecutiveErrors = 0;
    await _ttsStop();
    _emitState();
  }

  @override
  Future<void> updateVoiceSettings({double? rate, double? pitch}) async {
    if (rate != null) await _ttsSetRate(rate);
    if (pitch != null) await _ttsSetPitch(pitch);
    if (_playing && (rate != null || pitch != null)) {
      await _ttsStop();
      await _speakCurrent();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_useNative) {
      _nativeTts?.dispose();
    } else {
      _tts?.stop();
    }
    _stateController.close();
  }

  // ── 朗读控制 ──────────────────────────────────────────

  Future<void> _speakCurrent() async {
    if (!_playing || _disposed) return;
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      debugPrint('[TTS] 连续错误超过 $_maxConsecutiveErrors 次，停止朗读');
      await stop();
      return;
    }
    if (_paragraphIndex >= _currentParagraphs.length) {
      _chapterIndex++;
      if (_chapterIndex >= _allChapters.length) {
        _playing = false;
        _emitState();
        return;
      }
      _currentParagraphs = _splitParagraphs(_allChapters[_chapterIndex]);
      _paragraphIndex = 0;
      _emitState();
    }

    final rawText = _currentParagraphs[_paragraphIndex];
    if (rawText.trim().isEmpty) {
      _paragraphIndex++;
      await _speakCurrent();
      return;
    }

    final correctedText = await _corrector.correct(rawText);
    try {
      _consecutiveErrors = 0;
      await _ttsSpeak(correctedText);
    } catch (e) {
      _consecutiveErrors++;
      debugPrint('[TTS] speak() 调用失败 ($_consecutiveErrors次): $e');
      _speakNext();
    }
  }

  void _speakNext() {
    if (!_playing || _disposed) return;
    _paragraphIndex++;
    _emitState();
    _speakCurrent();
  }

  List<String> _splitParagraphs(String text) {
    return text
        .split(RegExp(r'\n{1,}'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _emitState() {
    if (_disposed) return;
    _stateController.add(TtsState(
      isPlaying: _playing,
      chapterIndex: _chapterIndex,
      paragraphIndex: _paragraphIndex,
      totalParagraphs: _currentParagraphs.length,
      currentUnitText: _paragraphIndex < _currentParagraphs.length
          ? _currentParagraphs[_paragraphIndex]
          : '',
    ));
  }
}
