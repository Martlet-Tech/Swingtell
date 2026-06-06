import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/reader_settings.dart';
import '../../services/settings_service.dart';
import 'tts_text_corrector.dart';
import 'tts_pipeline.dart';
import 'native_tts.dart';
import 'llm_correction_worker.dart';

class TtsPipelineImpl implements TtsPipeline {
  final TtsTextCorrector _corrector;
  final SettingsService _settings;
  FlutterTts? _tts;
  NativeTts? _nativeTts;
  bool _useNative = false;
  final _stateController = StreamController<TtsState>.broadcast();

  List<String> _allChapters = [];
  List<String> _currentUnits = [];
  int _chapterIndex = 0;
  int _unitIndex = 0;
  List<String> _subQueue = [];
  int _subIndex = 0;
  bool _playing = false;
  bool _disposed = false;
  int _consecutiveErrors = 0;
  int _ttsErrorCount = 0;
  static const int _maxConsecutiveErrors = 3;

  // ── LLM 模式专用字段 ──
  LLMCorrectionWorker? _llmWorker;
  final List<_LLMParagraph> _llmParagraphs = [];

  TtsPipelineImpl({
    TtsTextCorrector? corrector,
    required SettingsService settings,
  })  : _corrector = corrector ?? PassthroughCorrector(),
       _settings = settings;

  @override
  bool get isPlaying => _playing;

  @override
  Stream<TtsState> get stateStream => _stateController.stream;

  @override
  Future<void> init() async {
    final tts = FlutterTts();
    dynamic engines;
    try {
      engines = await tts.getEngines;
    } catch (_) {
      engines = null;
    }

    final engineList = (engines is List ? engines.cast<String>() : <String>[]);
    if (engineList.isNotEmpty) {
      _tts = tts;
      await _useFlutterTts();
      debugPrint('[TTS] 使用 flutter_tts 引擎');
      return;
    }

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
          _speakCurrent();
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
      _speakCurrent();
    });
    tts.setErrorHandler((msg) {
      debugPrint('[TTS] flutter_tts 错误: $msg | _playing=$_playing _disposed=$_disposed');
      if (!_playing || _disposed) return;
      _ttsErrorCount++;
      if (_ttsErrorCount >= _maxConsecutiveErrors) {
        debugPrint('[TTS] flutter_tts 连续错误超过 $_maxConsecutiveErrors 次，停止朗读');
        _playing = false;
        _emitState();
        return;
      }
      _speakNext();
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
    _llmWorker?.cancel();
    _llmWorker = null;

    _allChapters = chapterTexts;
    _chapterIndex = chapterIndex;
    _currentUnits = _splitIntoReadingUnits(chapterTexts[chapterIndex]);
    _unitIndex = paragraphOffset;
    _subQueue = [];
    _subIndex = 0;
    _consecutiveErrors = 0;
    _llmParagraphs.clear();

    final mode = _settings.settings.ttsCorrectionMode;

    if (mode == TtsCorrectionMode.llm) {
      final apiKey = _settings.settings.aiApiKey;
      if (apiKey.isEmpty) {
        _stateController.add(TtsState(
          isPlaying: false,
          chapterIndex: chapterIndex,
          paragraphIndex: paragraphOffset,
          totalParagraphs: 0,
          error: '请先在设置中填写 AI API Key',
        ));
        return;
      }

      final remainingText = _buildRemainingText(
          chapterTexts, chapterIndex, paragraphOffset);

      if (remainingText.isEmpty) {
        _playing = false;
        _emitState();
        return;
      }

      final s = _settings.settings;
      _llmWorker = LLMCorrectionWorker(
        apiKey: apiKey,
        apiUrl: s.aiApiUrl,
        model: s.aiModel,
        batchChars: s.llmBatchChars,
        maxBufferChunks: (s.llmBufferChars / s.llmBatchChars).ceil() * 2,
      );
      _llmWorker!.start(remainingText);
    }

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
    _subQueue = [];
    _subIndex = 0;
    _emitState();
    await _speakCurrent();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _unitIndex = 0;
    _consecutiveErrors = 0;
    _subQueue = [];
    _subIndex = 0;
    _llmParagraphs.clear();
    _llmWorker?.cancel();
    _llmWorker = null;
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
  Future<void> updateCorrectionMode(TtsCorrectionMode mode) async {
    if (_playing) return;
    await _settings.update(_settings.settings.copyWith(ttsCorrectionMode: mode));
  }

  @override
  void dispose() {
    _disposed = true;
    _llmWorker?.cancel();
    _llmWorker = null;
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

    if (_llmWorker != null) {
      await _speakCurrentLLM();
      return;
    }

    // 当前段落的子队列还有剩余，继续送
    if (_subIndex < _subQueue.length) {
      final fragment = _subQueue[_subIndex];
      _subIndex++;
      final corrected = await _corrector.correct(fragment);
      debugPrint('[TTS] speak unitIndex=$_unitIndex '
          'sub=$_subIndex/${_subQueue.length} text="${corrected.substring(0, min(20, corrected.length))}"');
      try {
        await _ttsSpeak(corrected);
        _consecutiveErrors = 0;
      } catch (e) {
        _consecutiveErrors++;
        debugPrint('[TTS] speak() catch: $e');
      }
      return;
    }

    // 子队列耗尽，推进到下一个主段落
    // 首次进入（start/resume 时子队列从未消费过），停留在当前段落不跳过
    if (_subIndex > 0) {
      _unitIndex++;
    }
    while (true) {
      if (_unitIndex >= _currentUnits.length) {
        _chapterIndex++;
        if (_chapterIndex >= _allChapters.length) {
          _playing = false;
          _emitState();
          return;
        }
        _currentUnits = _splitIntoReadingUnits(_allChapters[_chapterIndex]);
        _unitIndex = 0;
        _emitState();
      }
      if (_currentUnits[_unitIndex].trim().isNotEmpty) break;
      _unitIndex++;
    }

    final text = _currentUnits[_unitIndex];
    _subQueue = _safeSplit(text);
    _subIndex = 0;

    _emitState();

    final fragment = _subQueue[_subIndex];
    _subIndex++;
    final corrected = await _corrector.correct(fragment);
    debugPrint('[TTS] speak unitIndex=$_unitIndex '
        'sub=1/${_subQueue.length} text="${corrected.substring(0, min(20, corrected.length))}"');
    try {
      await _ttsSpeak(corrected);
      _consecutiveErrors = 0;
    } catch (e) {
      _consecutiveErrors++;
      debugPrint('[TTS] speak() catch: $e');
    }
  }

  // ── LLM 模式 ──────────────────────────────────────────

  Future<void> _speakCurrentLLM() async {
    final buffer = _llmWorker!.buffer;

    if (_subIndex < _subQueue.length) {
      final fragment = _subQueue[_subIndex];
      _subIndex++;
      try {
        await _ttsSpeak(fragment);
        _consecutiveErrors = 0;
        _ttsErrorCount = 0;
      } catch (e) {
        _consecutiveErrors++;
      }
      return;
    }

    while (true) {
      if (buffer.error != null) {
        _playing = false;
        _emitStateWithError(buffer.error!);
        return;
      }

      _unitIndex++;
      if (_unitIndex < _llmParagraphs.length) {
        final p = _llmParagraphs[_unitIndex];
        if (p.corrected.trim().isEmpty) continue;

        _subQueue = _safeSplit(p.corrected);
        _subIndex = 0;
        _emitStateLLM(p.original);
        break;
      }

      final chunk = await buffer.take();

      if (buffer.error != null) {
        _playing = false;
        _emitStateWithError(buffer.error!);
        return;
      }

      if (chunk == null) {
        _playing = false;
        _emitState();
        return;
      }

      final originalUnits = _splitIntoReadingUnits(chunk.original);
      final correctedUnits = _splitIntoReadingUnits(chunk.corrected);

      if (originalUnits.length != correctedUnits.length) {
        debugPrint('[TTS-LLM] WARN: 段落数不匹配 '
            'original=${originalUnits.length} corrected=${correctedUnits.length}');
        for (int i = 0; i < originalUnits.length; i++) {
          _llmParagraphs.add(_LLMParagraph(
            originalUnits[i],
            i < correctedUnits.length ? correctedUnits[i] : originalUnits[i],
          ));
        }
      } else {
        for (int i = 0; i < originalUnits.length; i++) {
          _llmParagraphs.add(_LLMParagraph(
            originalUnits[i],
            correctedUnits[i],
          ));
        }
      }

      while (_unitIndex + 1 < _llmParagraphs.length &&
             _llmParagraphs[_unitIndex + 1].corrected.trim().isEmpty) {
        _unitIndex++;
      }
    }

    if (_subQueue.isNotEmpty) {
      final fragment = _subQueue[_subIndex];
      _subIndex++;
      try {
        await _ttsSpeak(fragment);
        _consecutiveErrors = 0;
        _ttsErrorCount = 0;
      } catch (e) {
        _consecutiveErrors++;
      }
    }
  }

  void _speakNext() {
    if (!_playing || _disposed) return;
    _unitIndex++;
    _subQueue = [];
    _subIndex = 0;
    _emitState();
    _speakCurrent();
  }

  // ── 工具方法 ──────────────────────────────────────────

  String _buildRemainingText(
      List<String> chapterTexts, int chapterIndex, int paragraphOffset) {
    final buf = StringBuffer();

    for (int ch = chapterIndex; ch < chapterTexts.length; ch++) {
      final paragraphs = _splitIntoReadingUnits(chapterTexts[ch]);
      final start = (ch == chapterIndex) ? paragraphOffset : 0;

      for (int i = start; i < paragraphs.length; i++) {
        if (buf.isNotEmpty) buf.write('\n');
        buf.write(paragraphs[i]);
      }
    }

    return buf.toString();
  }

  List<String> _safeSplit(String text, {int maxLen = 60}) {
    if (text.length <= maxLen) return [text];

    final result = <String>[];

    final parts = text.split(RegExp(r'(?<=[，。！？；：、,!?;:…])'));

    final buffer = StringBuffer();
    for (final part in parts) {
      if (buffer.length + part.length <= maxLen) {
        buffer.write(part);
      } else {
        if (buffer.isNotEmpty) {
          result.add(buffer.toString());
          buffer.clear();
        }
        if (part.length <= maxLen) {
          buffer.write(part);
        } else {
          var remaining = part;
          while (remaining.length > maxLen) {
            result.add(remaining.substring(0, maxLen));
            remaining = remaining.substring(maxLen);
          }
          if (remaining.isNotEmpty) buffer.write(remaining);
        }
      }
    }
    if (buffer.isNotEmpty) result.add(buffer.toString());

    return result.where((s) => s.trim().isNotEmpty).toList();
  }

  List<String> _splitIntoReadingUnits(String text) {
    return text
        .split(RegExp(r'\n{1,}'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ── emitState ──────────────────────────────────────────

  void _emitState() {
    if (_disposed) return;
    final unitText = _unitIndex < _currentUnits.length
        ? _currentUnits[_unitIndex]
        : '';
    _stateController.add(TtsState(
      isPlaying: _playing,
      chapterIndex: _chapterIndex,
      paragraphIndex: _unitIndex,
      totalParagraphs: _currentUnits.length,
      currentUnitText: unitText,
    ));
  }

  void _emitStateLLM(String originalText) {
    if (_disposed) return;
    _stateController.add(TtsState(
      isPlaying: _playing,
      chapterIndex: _chapterIndex,
      paragraphIndex: _unitIndex,
      totalParagraphs: _llmParagraphs.length,
      currentUnitText: originalText,
    ));
  }

  void _emitStateWithError(String msg) {
    if (_disposed) return;
    _stateController.add(TtsState(
      isPlaying: false,
      chapterIndex: _chapterIndex,
      paragraphIndex: _unitIndex,
      totalParagraphs: _llmParagraphs.length,
      error: msg,
    ));
  }
}

class _LLMParagraph {
  final String original;
  final String corrected;
  const _LLMParagraph(this.original, this.corrected);
}

