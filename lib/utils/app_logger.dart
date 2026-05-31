import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum LogLevel { debug, info, warn, error }

class AppLogger {
  static final AppLogger _instance = AppLogger._();
  static AppLogger get instance => _instance;

  AppLogger._();

  bool _initialized = false;
  IOSink? _sink;
  String _currentDate = '';
  String _logDir = '';
  StreamSubscription<FlutterErrorDetails>? _flutterErrorSub;
  Timer? _flushTimer;

  Future<void> init() async {
    if (_initialized) return;
    final appDir = await getApplicationDocumentsDirectory();
    _logDir = p.join(appDir.path, 'logs');
    await Directory(_logDir).create(recursive: true);
    _cleanOldLogs();
    await _openLogForToday();
    _captureErrors();
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) => _flush());
    _initialized = true;
  }

  void debug(String msg) => _log(LogLevel.debug, msg);
  void info(String msg) => _log(LogLevel.info, msg);
  void warn(String msg) => _log(LogLevel.warn, msg);
  void error(String msg, [Object? e, StackTrace? st]) {
    _log(LogLevel.error, msg);
    if (e != null) _log(LogLevel.error, '  └─ $e');
    if (st != null) {
      for (final line in st.toString().split('\n')) {
        _log(LogLevel.error, '     $line');
      }
    }
  }

  Future<String> getRecentContent({int maxLines = 2000}) async {
    await _flush();
    final files = _listLogFiles();
    if (files.isEmpty) return '(no logs)';
    final latest = files.last;
    final lines = await latest.readAsLines();
    if (lines.length <= maxLines) return lines.join('\n');
    return '(showing last $maxLines of ${lines.length} lines)\n'
        '${lines.skip(lines.length - maxLines).join('\n')}';
  }

  String? get latestLogPath {
    final files = _listLogFiles();
    return files.isNotEmpty ? files.last.path : null;
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    _flutterErrorSub?.cancel();
    await _flush();
    await _sink?.close();
    _sink = null;
    _initialized = false;
  }

  // --- private ---

  void _log(LogLevel level, String msg) {
    final timestamp = _formatTime(DateTime.now());
    final prefix = level.name.toUpperCase().padRight(5);
    final line = '[$timestamp] $prefix | $msg';
    debugPrint(line);
    _write(line);
  }

  void _write(String line) {
    if (_sink == null) return;
    try {
      _sink!.writeln(line);
    } catch (_) {}
  }

  Future<void> _flush() async {
    try {
      await _sink?.flush();
    } catch (_) {}
  }

  Future<void> _openLogForToday() async {
    await _sink?.close();
    _currentDate = _dateString(DateTime.now());
    final path = p.join(_logDir, 'swingtell_$_currentDate.log');
    _sink = File(path).openWrite(mode: FileMode.append);
  }

  void _cleanOldLogs() {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final cutoffStr = _dateString(cutoff);
      for (final file in _listLogFiles()) {
        final name = p.basenameWithoutExtension(file.path);
        if (name.compareTo('swingtell_$cutoffStr') < 0) {
          file.deleteSync();
        }
      }
    } catch (_) {}
  }

  List<File> _listLogFiles() {
    try {
      return Directory(_logDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
    } catch (_) {
      return [];
    }
  }

  void _captureErrors() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      error('FlutterError: ${details.exception}', details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (exception, stack) {
      error('Unhandled error', exception, stack);
      return true;
    };
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  static String _dateString(DateTime dt) {
    return '${dt.year}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}
