import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'correction_ring_buffer.dart';

const _kPolyphonic = {
  '行','长','重','了','着','还','为','都','没','乐','好','教','觉','朝',
  '藏','差','传','调','发','分','给','供','假','间','将','角','结',
  '量','率','难','强','曲','数','相','应','与','中','种','转','倒',
  '当','的','得','地','只','奇','切','兴','更','少','大','背','奔','便',
  '别','泊','参','曾','称','乘','处','创','从','斗','度','肚',
  '恶','否','佛','父','勾','观','冠','龟','哈','汗','荷',
  '核','横','虹','糊','华','划','会','混','纪','系','夹','贾',
  '监','渐','藉','禁','劲','据','卷','看','壳','空','括','拉','烙',
  '勒','擂','累','俩','撩','淋','令','溜','馏','陆','捋','落',
  '埋','脉','氓','蒙','秘','模','磨','抹','那','溺','拧','宁','弄',
  '排','迫','仆','铺','曝','栖','蹊','翘','亲','苘','区',
  '圈','任','散','丧','扫','色','刹','扇','上','舍','摄','甚',
  '省','识','食','氏','熟','属','术','刷','衰','拴','说','似','松',
  '宿','遂','踏','苔','趟','提','体','挑','帖','通','同','吐','褪','拓',
  '瓦','委','尾','尉','遗','蔚','文','窝','乌','无','洗','吓','鲜',
  '巷','削','校','血','熏','压','哑','咽','殷','饮','佣','拥',
  '吁','於','予','雨','语','员','轧','炸','栅','粘','占','涨',
  '正','症','挣','殖','指','质','轴','著','幢',
  '琢','仔','作','坐',
};

class LLMCorrectionWorker {
  final String apiKey;
  final String apiUrl;
  final String model;
  final int batchChars;
  final CorrectionRingBuffer buffer;

  bool _cancelled = false;
  String _context = '';

  LLMCorrectionWorker({
    required this.apiKey,
    required this.apiUrl,
    required this.model,
    required this.batchChars,
    int maxBufferChunks = 6,
  }) : buffer = CorrectionRingBuffer(maxChunks: maxBufferChunks);

  void start(String remainingText, {String context = ''}) {
    _cancelled = false;
    _context = context;
    debugPrint('[TTS-LLM] worker start, textLen=${remainingText.length} batchChars=$batchChars${context.isNotEmpty ? ' ctx=$context' : ''}');
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
      debugPrint('[TTS-LLM] chunk ${pos}/${text.length} rawLen=${rawChunk.length}');

      String corrected;
      if (!_containsPolyphonic(rawChunk)) {
        corrected = rawChunk;
        debugPrint('[TTS-LLM] passthrough (no polyphonic chars)');
      } else {
        try {
          corrected = await _callLLM(rawChunk);
          final diff = _diffHighlight(rawChunk, corrected);
          debugPrint('[TTS-LLM] LLM OK, correctedLen=${corrected.length} diff=$diff');
        } catch (e) {
          debugPrint('[TTS-LLM] LLM FAIL: $e');
          buffer.setError('LLM 纠错失败: $e');
          return;
        }
      }

      buffer.add(CorrectedChunk(rawChunk, corrected));

      while (!_cancelled && buffer.isFull) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    debugPrint('[TTS-LLM] worker done, cancelled=$_cancelled');
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

  bool _containsPolyphonic(String text) {
    for (int i = 0; i < text.length; i++) {
      if (_kPolyphonic.contains(text[i])) return true;
    }
    return false;
  }

  Future<String> _callLLM(String rawText) async {
    final sysPrompt = _context.isNotEmpty
        ? '$_systemPrompt\n当前文段出自$_context。'
        : _systemPrompt;
    final request = http.Request('POST', Uri.parse('$apiUrl/chat/completions'));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': sysPrompt},
        {'role': 'user', 'content': '请将以下中文文本中的多音字替换为同音单音字：\n\n$rawText'},
      ],
      'stream': false,
      'temperature': 0.0,
      'max_tokens': 4096,
      'thinking': {'type': 'disabled'},
    });

    for (int retry = 0; retry < 3; retry++) {
      try {
        final streamed = await http.Client()
            .send(request)
            .timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamed);
        debugPrint('[TTS-LLM] API raw: status=${response.statusCode} '
            'bodyLen=${response.body.length} '
            'body="${response.body.substring(0, min(200, response.body.length))}"');

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

  String _diffHighlight(String original, String corrected) {
    final buf = StringBuffer();
    final len = min(original.length, corrected.length);
    for (int i = 0; i < len; i++) {
      if (original[i] != corrected[i]) {
        buf.write('[$i:${original[i]}→${corrected[i]}]');
        if (buf.length > 250) { buf.write('...'); break; }
      }
    }
    if (buf.isEmpty) buf.write('(无变化)');
    return buf.toString();
  }

  static const _systemPrompt = '''
你是一个中文 TTS 预处理助手。你的任务是将用户提供的中文文本中的多音字替换为同音单音字，
使 TTS 引擎朗读时不会出现多音字读错的情况。

严格规则：
1. 只替换多音字，其他字符原样保留。非多音字严禁改动。
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
