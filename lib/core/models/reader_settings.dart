import 'package:hive/hive.dart';

part 'reader_settings.g.dart';

@HiveType(typeId: 2)
class ReaderSettings extends HiveObject {
  @HiveField(0) String fontFamily = 'serif';
  @HiveField(1) double fontSize = 18.0;
  @HiveField(2) double lineHeight = 1.8;
  @HiveField(3) int colorThemeIndex = 0;
  @HiveField(4) double ttsSpeechRate = 0.5;
  @HiveField(6) double ttsPitch = 1.0;
  @HiveField(7) double ttsVolume = 1.0;
  @HiveField(8) String aiApiKey = '';
  @HiveField(9) String aiApiUrl = 'https://api.openai.com/v1';
  @HiveField(10) String aiModel = 'gpt-4o-mini';

  ReaderSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    int? colorThemeIndex,
    double? ttsSpeechRate,
    double? ttsPitch,
    double? ttsVolume,
    String? aiApiKey,
    String? aiApiUrl,
    String? aiModel,
  }) =>
      ReaderSettings()
        ..fontFamily = fontFamily ?? this.fontFamily
        ..fontSize = fontSize ?? this.fontSize
        ..lineHeight = lineHeight ?? this.lineHeight
        ..colorThemeIndex = colorThemeIndex ?? this.colorThemeIndex
        ..ttsSpeechRate = ttsSpeechRate ?? this.ttsSpeechRate
        ..ttsPitch = ttsPitch ?? this.ttsPitch
        ..ttsVolume = ttsVolume ?? this.ttsVolume
        ..aiApiKey = aiApiKey ?? this.aiApiKey
        ..aiApiUrl = aiApiUrl ?? this.aiApiUrl
        ..aiModel = aiModel ?? this.aiModel;
}
