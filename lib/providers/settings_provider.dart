import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage/settings_service.dart';

/// Singleton [SettingsService] — shared by ReaderNotifier, TtsSettingsSheet, etc.
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});
