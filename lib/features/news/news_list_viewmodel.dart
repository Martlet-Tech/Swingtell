import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/news_topic.dart';
import '../../core/services/news_storage_service.dart';
import '../../core/services/rss_service.dart';

class NewsListViewModel extends ChangeNotifier {
  final NewsStorageService _storage;
  List<NewsTopic> _topics = [];
  bool _loading = true;

  NewsListViewModel(this._storage);

  List<NewsTopic> get topics => _topics;
  bool get isLoading => _loading;
  String? get globalPrompt => _storage.globalPrompt;
  bool get webSearchEnabled => _storage.webSearchEnabled;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _topics = _storage.getAllTopics();
    _loading = false;
    notifyListeners();
  }

  Future<void> createTopic(String name, String prompt) async {
    final topic = NewsTopic()
      ..id = const Uuid().v4()
      ..name = name
      ..prompt = prompt
      ..createdAt = DateTime.now();
    await _storage.saveTopic(topic);
    _topics.insert(0, topic);
    notifyListeners();
  }

  Future<void> updateTopic(NewsTopic updated) async {
    await _storage.saveTopic(updated);
    final idx = _topics.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      _topics[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteTopic(String id) async {
    await _storage.deleteTopic(id);
    _topics.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> setGlobalPrompt(String value) async {
    await _storage.setGlobalPrompt(value);
    notifyListeners();
  }

  Future<void> setWebSearchEnabled(bool value) async {
    await _storage.setWebSearchEnabled(value);
    notifyListeners();
  }

  List<RssSource> get rssSources => _storage.rssSources;

  Future<void> addRssSource(RssSource source) async {
    final list = [...rssSources, source];
    await _storage.setRssSources(list);
    notifyListeners();
  }

  Future<void> removeRssSource(RssSource source) async {
    final list = rssSources.where((s) => s.url != source.url).toList();
    await _storage.setRssSources(list);
    notifyListeners();
  }

  Future<void> resetRssSources() async {
    await _storage.resetRssSources();
    notifyListeners();
  }
}
