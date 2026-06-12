import 'package:hive/hive.dart';

part 'reader_settings.g.dart';

enum TtsCorrectionMode {
  local,
  llm,
}

@HiveType(typeId: 2)
class ReaderSettings extends HiveObject {
  @HiveField(0) String fontFamily = 'serif';
  @HiveField(1) double fontSize = 18.0;
  @HiveField(2) double lineHeight = 1.8;
  @HiveField(3) int colorThemeIndex = 0;
  @HiveField(4) double ttsSpeechRate = 0.5;
  @HiveField(6) double ttsPitch = 1.0;
  @HiveField(8) String aiApiKey = '';
  @HiveField(9) String aiApiUrl = 'https://api.openai.com/v1';
  @HiveField(10) String aiModel = 'gpt-4o-mini';
  @HiveField(11) bool keepScreenOn = false;
  @HiveField(12) int ttsCorrectionModeIndex = 0;
  @HiveField(13) int llmBufferChars = 1500;
  @HiveField(14) int llmBatchChars = 500;
  @HiveField(15) DateTime? timelineAnchorReal;
  @HiveField(16) DateTime? timelineAnchorHistory;

  TtsCorrectionMode get ttsCorrectionMode =>
      TtsCorrectionMode.values[ttsCorrectionModeIndex];
  set ttsCorrectionMode(TtsCorrectionMode mode) =>
      ttsCorrectionModeIndex = mode.index;

  DateTime? get todayInTimeline {
    if (timelineAnchorReal == null || timelineAnchorHistory == null) return null;
    final offsetDays = DateTime.now().difference(timelineAnchorReal!).inDays;
    return timelineAnchorHistory!.add(Duration(days: offsetDays));
  }

  ReaderSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    int? colorThemeIndex,
    double? ttsSpeechRate,
    double? ttsPitch,
    String? aiApiKey,
    String? aiApiUrl,
    String? aiModel,
    bool? keepScreenOn,
    TtsCorrectionMode? ttsCorrectionMode,
    int? llmBufferChars,
    int? llmBatchChars,
    DateTime? timelineAnchorReal,
    DateTime? timelineAnchorHistory,
  }) =>
      ReaderSettings()
        ..fontFamily = fontFamily ?? this.fontFamily
        ..fontSize = fontSize ?? this.fontSize
        ..lineHeight = lineHeight ?? this.lineHeight
        ..colorThemeIndex = colorThemeIndex ?? this.colorThemeIndex
        ..ttsSpeechRate = ttsSpeechRate ?? this.ttsSpeechRate
        ..ttsPitch = ttsPitch ?? this.ttsPitch
        ..aiApiKey = aiApiKey ?? this.aiApiKey
        ..aiApiUrl = aiApiUrl ?? this.aiApiUrl
        ..aiModel = aiModel ?? this.aiModel
        ..keepScreenOn = keepScreenOn ?? this.keepScreenOn
        ..ttsCorrectionMode = ttsCorrectionMode ?? this.ttsCorrectionMode
        ..llmBufferChars = llmBufferChars ?? this.llmBufferChars
        ..llmBatchChars = llmBatchChars ?? this.llmBatchChars
        ..timelineAnchorReal = timelineAnchorReal ?? this.timelineAnchorReal
        ..timelineAnchorHistory = timelineAnchorHistory ?? this.timelineAnchorHistory;
}
