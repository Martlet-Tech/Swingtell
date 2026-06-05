import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'correction_ring_buffer.dart';

class LLMCorrectionWorker {
  final String apiKey;
  final String apiUrl;
  final String model;
  final int batchChars;
  final CorrectionRingBuffer buffer;

  bool _cancelled = false;

  LLMCorrectionWorker({
    required this.apiKey,
    required this.apiUrl,
    required this.model,
    required this.batchChars,
    int maxBufferChunks = 6,
  }) : buffer = CorrectionRingBuffer(maxChunks: maxBufferChunks);

  void start(String remainingText) {
    _cancelled = false;
    _run(remainingText);
  }

  void cancel() {
    _cancelled = true;
    buffer.close();
  }

  Future<void> _run(String text) async {
    int pos = 0;

    while (!_cancelled && pos < text.length) {
      final rawChunk = _smartChunk(text, pos, batchChars);
      if (rawChunk.isEmpty) break;
      pos += rawChunk.length;

      String corrected;
      try {
        corrected = await _callLLM(rawChunk);
      } catch (e) {
        buffer.setError('LLM 纠错失败: $e');
        return;
      }

      buffer.add(CorrectedChunk(rawChunk, corrected));

      while (!_cancelled && buffer.isFull) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    buffer.close();
  }

  String _smartChunk(String text, int start, int maxLen) {
    final end = start + maxLen;
    if (end >= text.length) return text.substring(start);

    final segment = text.substring(start, end);
    final match = RegExp(r'[。！？\n]').allMatches(segment);

    if (match.isNotEmpty) {
      final lastPunct = match.last;
      return text.substring(start, start + lastPunct.start + 1);
    }

    final weakMatch = RegExp(r'[，；：、]').allMatches(segment);
    if (weakMatch.isNotEmpty) {
      final lastWeak = weakMatch.last;
      return text.substring(start, start + lastWeak.start + 1);
    }

    return text.substring(start, end);
  }

  Future<String> _callLLM(String rawText) async {
    final request = http.Request('POST', Uri.parse('$apiUrl/chat/completions'));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': '请将以下中文文本中的多音字替换为同音单音字：\n\n$rawText'},
      ],
      'stream': false,
      'temperature': 0.0,
      'max_tokens': 4096,
    });

    for (int retry = 0; retry < 3; retry++) {
      try {
        final streamed = await http.Client()
            .send(request)
            .timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode != 200) {
          throw Exception('API ${response.statusCode}');
        }

        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String?;
        if (content == null) throw Exception('空响应');
        return content.trim();
      } catch (e) {
        if (retry == 2) rethrow;
        await Future.delayed(Duration(seconds: retry + 1));
      }
    }
    throw Exception('重试耗尽');
  }

  static const _systemPrompt = '''
你是一个中文 TTS 预处理助手。你的任务是将用户提供的中文文本中的多音字替换为同音单音字，
使 TTS 引擎朗读时不会出现多音字读错的情况。

严格规则：
1. 只替换多音字，其他字符原样保留
2. 替换后的字必须与原字发音相同（在目标语境下）
3. 保持所有标点符号、换行符（\n）不变
4. 不要增删任何字符，总字数必须严格相等
5. 只输出替换后的文本，不要任何解释、标记或说明

示例：
输入：银行行长今天去种地
输出：银杭杭掌今天去重地

输入：我们需要重新审视这个重要的问题
输出：我们需要从新审视这个重要的问题
''';
}
