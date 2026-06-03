import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/reader_settings.dart';

class SettingsService extends ChangeNotifier {
  late Box<ReaderSettings> _box;
  late ReaderSettings _settings;

  ReaderSettings get settings => _settings;

  Future<void> init() async {
    _box = await Hive.openBox<ReaderSettings>('settings');
    _settings = _box.get('current') ?? ReaderSettings();
  }

  Future<void> update(ReaderSettings updated) async {
    _settings = updated;
    await _box.put('current', updated);
    notifyListeners();
  }
}
