import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/rss_item.dart';
import 'rss_service.dart';
import 'settings_service.dart';

class NewsService {
  final SettingsService _settings;

  NewsService(this._settings);

  Future<String> getNewsSummary({
    required String topicPrompt,
    required String timeRange,
    String? globalPrompt,
    bool webSearchEnabled = false,
    List<RssSource>? rssSources,
    void Function(String logEntry)? onProgress,
  }) async {
    final apiKey = _settings.settings.aiApiKey;
    final apiUrl = _settings.settings.aiApiUrl;
    final model = _settings.settings.aiModel;

    if (apiKey.isEmpty) {
      return '<p style="color:red;padding:20px;">请先在设置页填写 API Key</p>';
    }

    List<RssItem>? articles;
    if (rssSources != null && rssSources.isNotEmpty) {
      final rssService = RssService();
      onProgress?.call('📡 正在获取 RSS 新闻源…');
      articles = await rssService.fetchAll(
        rssSources,
        maxAge: _maxAgeForTimeRange(timeRange),
        onStatus: (name, success, count) {
          if (success) {
            onProgress?.call('  ✓ $name（$count 条）');
          } else {
            onProgress?.call('  ✗ $name（获取失败）');
          }
        },
      );
    }

    final systemPrompt = _buildSystemPrompt(globalPrompt, articles != null && articles.isNotEmpty);
    onProgress?.call('🤖 正在让 AI 分析总结…');
    final userMessage = _buildUserMessage(topicPrompt, timeRange, articles);

    try {
      final requestBody = <String, dynamic>{
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'stream': false,
      };
      if (webSearchEnabled) {
        requestBody['enable_search'] = true;
      }

      final request = http.Request(
        'POST',
        Uri.parse('$apiUrl/chat/completions'),
      );
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(requestBody);

      final response = await http.Client().send(request);
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        return '<p style="color:red;padding:20px;">API 错误 ${response.statusCode}<br>$body</p>';
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final content = data['choices'][0]['message']['content'] as String? ?? '';
      if (data['usage'] != null && data['usage'] is Map) {
        final u = data['usage'] as Map<String, dynamic>;
        onProgress?.call('usage:${u['prompt_tokens']},${u['completion_tokens']},${u['total_tokens']}');
      }
      return content;
    } catch (e) {
      return '<p style="color:red;padding:20px;">请求失败: $e</p>';
    }
  }

  Duration _maxAgeForTimeRange(String timeRange) {
    switch (timeRange) {
      case '12小时':
        return const Duration(hours: 12);
      case '24小时':
        return const Duration(hours: 24);
      case '48小时':
        return const Duration(hours: 48);
      case '1周':
        return const Duration(days: 7);
      default:
        return const Duration(days: 7);
    }
  }

  String _buildSystemPrompt(String? globalPrompt, bool hasRssArticles) {
    final buf = StringBuffer();
    if (hasRssArticles) {
      buf.write('你是一个新闻分析师。以下是用户从各新闻源获取的最新文章列表。'
          '请从中筛选出与用户关注的新闻话题相关的文章，按重要性排序，'
          '用HTML格式输出总结。\n\n'
          '要求：\n'
          '1. 只从提供的文章列表中筛选，不要编造文章\n'
          '2. 用HTML格式返回结果，只返回可放入<body>的HTML片段，'
          '不要包含<html>/<head>/<body>标签，不要用markdown代码块包裹\n'
          '3. 每条新闻用以下结构呈现：\n'
          '   <div class="news-item">\n'
          '     <h3>新闻标题</h3>\n'
          '     <div class="meta">发布时间 | 来源</div>\n'
          '     <p>你的总结</p>\n'
          '     <a class="source-link" href="原文URL" target="_blank">'
          '阅读原文 →</a>\n'
          '   </div>\n'
          '4. href必须使用文章提供的原始链接\n'
          '5. 按重要性排序，最重要放在最前面\n'
          '6. 如果没有相关文章，请如实说明\n');
    } else {
      buf.write('你是一个新闻分析师。\n\n'
          '要求：\n'
          '1. 用HTML格式返回结果，只返回可放入<body>的HTML片段，'
          '不要包含<html>/<head>/<body>标签，不要用markdown代码块包裹\n'
          '2. 每条新闻用以下结构呈现：\n'
          '   <div class="news-item">\n'
          '     <h3>新闻标题</h3>\n'
          '     <div class="meta">发布时间 | 来源</div>\n'
          '     <p>总结内容</p>\n'
          '     <a class="source-link" href="实际来源URL" target="_blank">'
          '阅读原文 →</a>\n'
          '   </div>\n'
          '3. 如果你有能力联网搜索，请搜索该话题的最新新闻并返回真实结果'
          '（附上真实可访问的原文链接）\n'
          '4. 如果你无法联网搜索，则基于你的训练数据中该时间范围内的事件来回答，'
          '并在每条新闻末尾标注信息来源的可靠性（"基于训练数据"或"推测"）\n'
          '5. 按重要性排序，最重要放在最前面\n'
          '6. 如果该时间范围内没有相关事件，请如实说明\n'
          '7. 确保链接的href包含完整的https://开头的URL\n');
    }
    if (globalPrompt != null && globalPrompt.isNotEmpty) {
      buf.write('\n额外风格要求：$globalPrompt');
    }
    return buf.toString();
  }

  String _buildUserMessage(
      String topicPrompt, String timeRange, List<RssItem>? articles) {
    final now = DateTime.now();
    final buf = StringBuffer();
    buf.writeln('当前日期：${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    buf.writeln('关注点：$topicPrompt');
    buf.writeln('时间范围：最近$timeRange');

    if (articles != null && articles.isNotEmpty) {
      buf.writeln('\n以下是从各新闻源获取的最新文章列表：');
      for (var i = 0; i < articles.length; i++) {
        buf.writeln(articles[i].toPromptString(i + 1));
      }
    }

    return buf.toString();
  }
}
