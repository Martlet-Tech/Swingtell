enum TtsEventType { progress, completed, error, word }

class TtsEvent {
  final TtsEventType type;
  final String? word;
  final int? start;
  final int? end;
  final String? error;

  TtsEvent({required this.type, this.word, this.start, this.end, this.error});
}

abstract class TtsEngine {
  Future<void> init();
  Future<void> speak(String text);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> setSpeed(double speed);
  Future<void> setVoice(String voiceId);
  Stream<TtsEvent> get events;
  bool get isPlaying;
  bool get isPaused;
  Future<void> dispose();
}
