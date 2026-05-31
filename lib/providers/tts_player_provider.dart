import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tts/device_tts.dart';
import '../services/tts/tts_player.dart';

/// Singleton [TtsPlayer] that lives beyond any single page.
///
/// Created once at app startup and disposed when the provider scope is torn
/// down. Pages read the player from this provider instead of creating their
/// own [DeviceTts] instance, enabling background playback and decoupling
/// the TTS lifecycle from the reader page.
final ttsPlayerProvider = Provider<TtsPlayer>((ref) {
  final player = TtsPlayer(DeviceTts());
  ref.onDispose(() => player.dispose());
  return player;
});
