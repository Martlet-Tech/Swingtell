import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/news_topic.dart';
import '../models/news_summary_record.dart';
import 'rss_service.dart';

class NewsStorageService {
  late Box<NewsTopic> _topicBox;
  late Box<String> _metaBox;

  static const _kGlobalPromptKey = 'global_prompt';
  static const _kWebSearchKey = 'web_search_enabled';
  static const _kRssSourcesKey = 'rss_sources';

  Future<void> init() async {
    _topicBox = await Hive.openBox<NewsTopic>('news_topics');
    _metaBox = await Hive.openBox<String>('news_meta');
  }

  List<NewsTopic> getAllTopics() {
    final topics = _topicBox.values.toList();
    topics.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return topics;
  }

  Future<void> saveTopic(NewsTopic topic) => _topicBox.put(topic.id, topic);

  Future<void> deleteTopic(String id) => _topicBox.delete(id);

  String? get globalPrompt => _metaBox.get(_kGlobalPromptKey);

  Future<void> setGlobalPrompt(String value) =>
      _metaBox.put(_kGlobalPromptKey, value);

  bool get webSearchEnabled => _metaBox.get(_kWebSearchKey) == 'true';

  Future<void> setWebSearchEnabled(bool value) =>
      _metaBox.put(_kWebSearchKey, value.toString());

  List<RssSource> get rssSources {
    final raw = _metaBox.get(_kRssSourcesKey);
    if (raw == null || raw.isEmpty) {
      return List.from(RssService.kDefaultSources);
    }
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => RssSource.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return List.from(RssService.kDefaultSources);
    }
  }

  Future<void> setRssSources(List<RssSource> sources) =>
      _metaBox.put(_kRssSourcesKey, jsonEncode(sources.map((s) => s.toJson()).toList()));

  Future<void> resetRssSources() => _metaBox.delete(_kRssSourcesKey);

  // ── 历史记录 ──

  Future<void> saveSummaryRecord(NewsSummaryRecord record) async {
    final box = await Hive.openBox<String>('news_history');
    await box.put(record.id, jsonEncode(record.toJson()));
  }

  Future<List<NewsSummaryRecord>> getRecordsForTopic(String topicId) async {
    final box = await Hive.openBox<String>('news_history');
    final records = box.values
        .map((v) => NewsSummaryRecord.fromJson(jsonDecode(v) as Map<String, dynamic>))
        .where((r) => r.topicId == topicId)
        .toList();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<void> deleteRecord(String recordId) async {
    final box = await Hive.openBox<String>('news_history');
    await box.delete(recordId);
  }
}
