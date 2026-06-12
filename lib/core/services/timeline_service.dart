import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'settings_service.dart';

class TimelineEntry {
  final DateTime historyDate;
  final String briefing;
  final List<String> rawEvents;
  final DateTime generatedAt;

  TimelineEntry({
    required this.historyDate,
    required this.briefing,
    required this.rawEvents,
    required this.generatedAt,
  });
}

class TimelineService {
  final SettingsService _settings;

  TimelineService(this._settings);

  bool get isConfigured =>
      _settings.settings.timelineAnchorReal != null &&
      _settings.settings.timelineAnchorHistory != null;

  DateTime? get todayInTimeline => _settings.settings.todayInTimeline;

  Future<void> setAnchor(DateTime realDate, DateTime historyDate) async {
    await _settings.update(_settings.settings.copyWith(
      timelineAnchorReal: realDate,
      timelineAnchorHistory: historyDate,
    ));
  }

  Future<void> clearAnchor() async {
    await _settings.update(_settings.settings.copyWith(
      timelineAnchorReal: null,
      timelineAnchorHistory: null,
    ));
  }

  Future<TimelineEntry> getToday() async {
    final historyDate = todayInTimeline;
    if (historyDate == null) throw Exception('世界线未设定');

    final cached = await _loadCache(historyDate);
    if (cached != null) return cached;

    final rawEvents = await _fetchWikiEvents(historyDate);
    final briefing = await _generateBriefing(historyDate, rawEvents);

    final entry = TimelineEntry(
      historyDate: historyDate,
      briefing: briefing,
      rawEvents: rawEvents,
      generatedAt: DateTime.now(),
    );

    await _saveCache(entry);
    return entry;
  }

  Future<List<String>> _fetchWikiEvents(DateTime date) async {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    try {
      return await _fetchFromWiki('zh', month, day, date.year);
    } catch (_) {
      try {
        return await _fetchFromWiki('en', month, day, date.year);
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<String>> _fetchFromWiki(
      String lang, String month, String day, int targetYear) async {
    final url =
        'https://$lang.wikipedia.org/api/rest_v1/feed/onthisday/events/$month/$day';
    final response = await http
        .get(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) throw Exception('维基请求失败');

    final data = jsonDecode(response.body);
    final events = data['events'] as List? ?? [];

    final filtered = events
        .where((e) => (e['year'] as int? ?? 0) <= targetYear)
        .map((e) {
          final year = e['year'];
          final text = e['text'] as String? ?? '';
          return '$year年：$text';
        })
        .take(15)
        .toList();

    return List<String>.from(filtered);
  }

  Future<String> _generateBriefing(
      DateTime date, List<String> rawEvents) async {
    final apiKey = _settings.settings.aiApiKey;
    final apiUrl = _settings.settings.aiApiUrl;
    final model = _settings.settings.aiModel;

    if (apiKey.isEmpty || rawEvents.isEmpty) {
      return _fallbackBriefing(date, rawEvents);
    }

    final dateStr = '${date.year}年${date.month}月${date.day}日';
    final eventsText = rawEvents.join('\n');

    final prompt =
        '你是一位生活在$dateStr的新闻播报员。\n'
        '以下是历史上$dateStr前后发生的事件：\n'
        '\n'
        '$eventsText\n'
        '\n'
        '请以第一人称"今日"视角，用200字左右写一份当日简报。\n'
        '要求：\n'
        '1. 只描述$dateStr当天或之前已发生的事，不提及未来\n'
        '2. 语气符合当时的时代背景\n'
        '3. 重点突出最重要的1-2件事\n'
        '4. 直接输出简报正文，不要任何解释或前言';

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$apiUrl/chat/completions'),
      );
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 500,
        'stream': false,
      });

      final response = await http.Client().send(request);
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['choices'][0]['message']['content'] as String;
    } catch (_) {
      return _fallbackBriefing(date, rawEvents);
    }
  }

  String _fallbackBriefing(DateTime date, List<String> rawEvents) {
    final dateStr = '${date.year}年${date.month}月${date.day}日';
    if (rawEvents.isEmpty) return '$dateStr：暂无历史记录';
    return '$dateStr 历史上的今天：\n\n${rawEvents.join('\n\n')}';
  }

  Future<File> _cacheFile(DateTime date) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/timeline');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return File('${folder.path}/$key.json');
  }

  Future<TimelineEntry?> _loadCache(DateTime date) async {
    try {
      final file = await _cacheFile(date);
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      return TimelineEntry(
        historyDate: DateTime.parse(data['historyDate']),
        briefing: data['briefing'],
        rawEvents: List<String>.from(data['rawEvents']),
        generatedAt: DateTime.parse(data['generatedAt']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(TimelineEntry entry) async {
    final file = await _cacheFile(entry.historyDate);
    final key =
        '${entry.historyDate.year}-${entry.historyDate.month.toString().padLeft(2, '0')}-${entry.historyDate.day.toString().padLeft(2, '0')}';
    await file.writeAsString(jsonEncode({
      'historyDate': key,
      'briefing': entry.briefing,
      'rawEvents': entry.rawEvents,
      'generatedAt': entry.generatedAt.toIso8601String(),
    }));
  }
}
