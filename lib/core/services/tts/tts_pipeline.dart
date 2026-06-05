import '../../models/reader_settings.dart';

class TtsState {
  final bool isPlaying;
  final int chapterIndex;
  final int paragraphIndex;
  final int totalParagraphs;
  final String currentUnitText;
  final String? error;

  const TtsState({
    required this.isPlaying,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.totalParagraphs,
    this.currentUnitText = '',
    this.error,
  });

  static const idle = TtsState(
    isPlaying: false,
    chapterIndex: 0,
    paragraphIndex: 0,
    totalParagraphs: 0,
  );
}

abstract class TtsPipeline {
  bool get isPlaying;
  Stream<TtsState> get stateStream;

  Future<void> init();

  Future<void> start({
    required List<String> chapterTexts,
    required int chapterIndex,
    int paragraphOffset = 0,
  });

  Future<void> pause();
  Future<void> resume();
  Future<void> stop();

  Future<void> updateVoiceSettings({double? rate, double? pitch});

  Future<void> updateCorrectionMode(TtsCorrectionMode mode);

  void dispose();
}
