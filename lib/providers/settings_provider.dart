import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/settings_repository.dart';

/// Singleton [SettingsRepository] — shared by ReaderNotifier, TtsSettingsSheet, etc.
///
/// 保持原 provider 名称不变，所有消费者无需改代码。
final settingsServiceProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});
