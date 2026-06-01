import 'package:shared_preferences/shared_preferences.dart';

/// 设置数据仓库
///
/// 统一读写 SharedPreferences，外界不直接接触持久化层。
class SettingsRepository {
  static const _keySpeed = 'tts_speed';
  static const _keyPitch = 'tts_pitch';
  static const _keyAutoNext = 'auto_next_chapter';

  Future<double> getSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySpeed) ?? 1.0;
  }

  Future<void> setSpeed(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeed, value);
  }

  Future<double> getPitch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyPitch) ?? 1.0;
  }

  Future<void> setPitch(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPitch, value);
  }

  Future<bool> getAutoNextChapter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoNext) ?? false;
  }

  Future<void> setAutoNextChapter(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoNext, value);
  }
}
