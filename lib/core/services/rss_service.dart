import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/rss_item.dart';

class RssSource {
  final String name;
  final String url;
  const RssSource(this.name, this.url);

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
  factory RssSource.fromJson(Map<String, dynamic> json) =>
      RssSource(json['name'] as String, json['url'] as String);

  @override
  bool operator ==(Object other) =>
      other is RssSource && url == other.url;
  @override
  int get hashCode => url.hashCode;
}

class RssService {
  static const kDefaultSources = [
    RssSource('NPR 新闻', 'https://feeds.npr.org/1001/rss.xml'),
    RssSource('Hacker News', 'https://hnrss.org/frontpage?count=20'),
    RssSource('中新网即时', 'https://www.chinanews.com.cn/rss/scroll-news.xml'),
    RssSource('中新网要闻', 'https://www.chinanews.com.cn/rss/importnews.xml'),
    RssSource('新华社时政', 'http://www.xinhuanet.com/politics/news_politics.xml'),
    RssSource('人民网时政', 'http://www.people.com.cn/rss/politics.xml'),
  ];

  Future<List<RssItem>> fetchAll(List<RssSource> sources,
      {Duration maxAge = const Duration(days: 7),
      void Function(String sourceName, bool success, int itemCount)? onStatus}) async {
    final cutoff = DateTime.now().subtract(maxAge);
    final futures = sources.map((s) async {
      final items = await _fetchSingle(s.url, s.name, cutoff);
      final success = items.isNotEmpty;
      onStatus?.call(s.name, success, items.length);
      return items;
    });
    final results = await Future.wait(futures, eagerError: false);
    final items = results.expand((list) => list).toList();
    items.sort((a, b) {
      final da = a.pubDate ?? DateTime(2000);
      final db = b.pubDate ?? DateTime(2000);
      return db.compareTo(da);
    });
    return items;
  }

  Future<List<RssItem>> _fetchSingle(
      String url, String sourceName, DateTime cutoff) async {
    try {
      final resp = await http
          .get(Uri.parse(url), headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          })
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      return _parse(resp.body, sourceName, cutoff);
    } catch (_) {
      return [];
    }
  }

  List<RssItem> _parse(String xmlStr, String sourceName, DateTime cutoff) {
    final doc = XmlDocument.parse(xmlStr);
    final root = doc.rootElement;

    if (root.name.local == 'rss') {
      return _parseRss(root, sourceName, cutoff);
    } else if (root.name.local == 'feed') {
      return _parseAtom(root, sourceName, cutoff);
    }
    return [];
  }

  List<RssItem> _parseRss(XmlElement rss, String sourceName, DateTime cutoff) {
    final channel = rss.findElements('channel').firstOrNull;
    if (channel == null) return [];
    return channel
        .findElements('item')
        .map((item) {
          final title = item.findElements('title').firstOrNull?.innerText ?? '';
          final link = item.findElements('link').firstOrNull?.innerText ?? '';
          final desc =
              item.findElements('description').firstOrNull?.innerText ?? '';
          final pubDateStr =
              item.findElements('pubDate').firstOrNull?.innerText ?? '';
          return RssItem(
            title: title,
            link: link,
            description: desc,
            pubDate: _parseDate(pubDateStr),
            sourceName: sourceName,
          );
        })
        .where((item) =>
            item.title.isNotEmpty &&
            item.link.isNotEmpty &&
            (item.pubDate == null || item.pubDate!.isAfter(cutoff)))
        .toList();
  }

  List<RssItem> _parseAtom(
      XmlElement feed, String sourceName, DateTime cutoff) {
    return feed
        .findElements('entry')
        .map((entry) {
          final title =
              entry.findElements('title').firstOrNull?.innerText ?? '';
          final linkEl = entry.findElements('link').firstOrNull;
          final link = linkEl?.getAttribute('href') ?? '';
          final summary = entry.findElements('summary').firstOrNull?.innerText ??
              entry.findElements('content').firstOrNull?.innerText ??
              '';
          final published = entry.findElements('published').firstOrNull?.innerText ??
              entry.findElements('updated').firstOrNull?.innerText ??
              '';
          return RssItem(
            title: title,
            link: link,
            description: summary,
            pubDate: _parseDate(published),
            sourceName: sourceName,
          );
        })
        .where((item) =>
            item.title.isNotEmpty &&
            item.link.isNotEmpty &&
            (item.pubDate == null || item.pubDate!.isAfter(cutoff)))
        .toList();
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return HttpDate.parse(dateStr);
    } catch (_) {}
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}
    try {
      // Handle non-standard RSS dates like "Fri,9-Dec-2022 11:49:16 GMT"
      var s = dateStr.trim();
      s = s.replaceFirst(RegExp(r'^(\w+,)(?! )'), r'$1 ');
      s = s.replaceFirstMapped(
        RegExp(r'(,\s+)(\d)(\D)'),
        (m) => '${m.group(1)}0${m.group(2)}${m.group(3)}',
      );
      s = s.replaceAllMapped(
        RegExp(r'(\d{2})-(\w{3})-(\d{4})'),
        (m) => '${m.group(1)} ${m.group(2)} ${m.group(3)}',
      );
      return HttpDate.parse(s);
    } catch (_) {}
    return null;
  }
}
