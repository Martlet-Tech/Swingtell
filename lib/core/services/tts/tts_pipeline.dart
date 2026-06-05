class TtsState {
  final bool isPlaying;
  final int chapterIndex;
  final int paragraphIndex;
  final int totalParagraphs;
  final String currentUnitText;
  const TtsState({
    required this.isPlaying,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.totalParagraphs,
    this.currentUnitText = '',
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

  void dispose();
}
