import 'package:flutter/foundation.dart';
import '../../core/services/timeline_service.dart';
import '../../core/services/tts/tts_pipeline.dart';

class TimelineViewModel extends ChangeNotifier {
  final TimelineService _service;
  final TtsPipeline _tts;

  TimelineEntry? entry;
  bool isLoading = false;
  String? error;

  TimelineViewModel({
    required TimelineService service,
    required TtsPipeline tts,
  })  : _service = service,
        _tts = tts;

  bool get isConfigured => _service.isConfigured;
  DateTime? get todayInTimeline => _service.todayInTimeline;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      entry = await _service.getToday();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAnchor(DateTime realDate, DateTime historyDate) async {
    await _service.setAnchor(realDate, historyDate);
    notifyListeners();
  }

  Future<void> clearAnchor() async {
    await _service.clearAnchor();
    entry = null;
    notifyListeners();
  }

  Stream<TtsState> get ttsStateStream => _tts.stateStream;

  Future<void> readAloud() async {
    if (entry == null) return;
    final units = entry!.briefing
        .split(RegExp(r'(?<=[。！？\n])'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    await _tts.stop();
    await _tts.start(
      chapterTexts: units,
      chapterIndex: 0,
    );
  }
}
