import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_character.dart';
import '../models/chat_message.dart';
import 'settings_service.dart';

class ChatService {
  final SettingsService _settings;

  ChatService(this._settings);

  Stream<String> sendMessage({
    required ChatCharacter character,
    required List<ChatMessage> recentMessages,
    required String userInput,
  }) async* {
    final apiKey = _settings.settings.aiApiKey;
    final apiUrl = _settings.settings.aiApiUrl;

    if (apiKey.isEmpty) {
      yield '请先在设置页填写 API Key';
      return;
    }

    final messages = <Map<String, dynamic>>[
      if (character.systemPrompt.isNotEmpty)
        {'role': 'system', 'content': character.systemPrompt},
      ...recentMessages.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userInput},
    ];

    try {
      final request = http.Request('POST', Uri.parse('$apiUrl/chat/completions'));
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': _settings.settings.aiModel,
        'messages': messages,
        'stream': true,
      });

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        yield 'API 错误: ${response.statusCode}';
        return;
      }

      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.startsWith('data: ') && chunk != 'data: [DONE]') {
          try {
            final data = jsonDecode(chunk.substring(6));
            final delta = data['choices'][0]['delta']['content'] as String?;
            if (delta != null) yield delta;
          } catch (_) {}
        }
      }
    } catch (e) {
      yield '请求失败: $e';
    }
  }
}
