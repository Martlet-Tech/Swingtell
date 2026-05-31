import 'package:shared_preferences/shared_preferences.dart';

/// Unified persistence layer for app settings.
///
/// Every setting read/write flows through this class so callers never
/// touch SharedPreferences directly.
class SettingsService {
  // Keys
  static const _keySpeed = 'tts_speed';
  static const _keyPitch = 'tts_pitch';
  static const _keyAutoNext = 'auto_next_chapter';

  // ---------------------------------------------------------------------------
  // Speed
  // ---------------------------------------------------------------------------

  Future<double> getSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySpeed) ?? 1.0;
  }

  Future<void> setSpeed(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeed, value);
  }

  // ---------------------------------------------------------------------------
  // Pitch
  // ---------------------------------------------------------------------------

  Future<double> getPitch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyPitch) ?? 1.0;
  }

  Future<void> setPitch(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPitch, value);
  }

  // ---------------------------------------------------------------------------
  // Auto-next chapter
  // ---------------------------------------------------------------------------

  Future<bool> getAutoNextChapter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoNext) ?? false;
  }

  Future<void> setAutoNextChapter(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoNext, value);
  }
}
