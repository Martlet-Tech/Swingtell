abstract class TtsTextCorrector {
  Future<String> correct(String rawText);
}

class PassthroughCorrector implements TtsTextCorrector {
  @override
  Future<String> correct(String rawText) async => rawText;
}
