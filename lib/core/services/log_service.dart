import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogService {
  static final LogService _instance = LogService._();
  factory LogService() => _instance;
  LogService._();

  File? _logFile;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/app.log');
  }

  Future<void> log(String message) async {
    if (_logFile == null) await init();
    await _logFile!.writeAsString(
      '[${DateTime.now().toIso8601String()}] $message\n',
      mode: FileMode.append,
    );
  }

  Future<String> getLogContent() async {
    if (_logFile == null || !await _logFile!.exists()) return '';
    return await _logFile!.readAsString();
  }

  Future<void> clear() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }
}
