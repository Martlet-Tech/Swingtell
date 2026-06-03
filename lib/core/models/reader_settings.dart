import 'package:hive/hive.dart';

part 'reader_settings.g.dart';

@HiveType(typeId: 2)
class ReaderSettings extends HiveObject {
  @HiveField(0) String fontFamily = 'serif';
  @HiveField(1) double fontSize = 18.0;
  @HiveField(2) double lineHeight = 1.8;
  @HiveField(3) int colorThemeIndex = 0;
  @HiveField(4) String readingMode = 'scroll';
  @HiveField(5) double ttsSpeechRate = 0.5;
  @HiveField(6) double ttsPitch = 1.0;
  @HiveField(7) double ttsVolume = 1.0;

  ReaderSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    int? colorThemeIndex,
    String? readingMode,
    double? ttsSpeechRate,
    double? ttsPitch,
    double? ttsVolume,
  }) =>
      ReaderSettings()
        ..fontFamily = fontFamily ?? this.fontFamily
        ..fontSize = fontSize ?? this.fontSize
        ..lineHeight = lineHeight ?? this.lineHeight
        ..colorThemeIndex = colorThemeIndex ?? this.colorThemeIndex
        ..readingMode = readingMode ?? this.readingMode
        ..ttsSpeechRate = ttsSpeechRate ?? this.ttsSpeechRate
        ..ttsPitch = ttsPitch ?? this.ttsPitch
        ..ttsVolume = ttsVolume ?? this.ttsVolume;
}
