import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/chat_character.dart';
import '../../core/models/chat_message.dart';
import '../../core/services/chat_storage_service.dart';
import '../../core/services/chat_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatStorageService _storage;
  final ChatService _chatService;
  final String _characterId;

  ChatCharacter? _character;
  List<ChatMessage> _messages = [];
  String _inputText = '';
  bool _loading = true;
  bool _sending = false;
  String _streamingContent = '';
  StreamSubscription<String>? _streamSub;

  ChatViewModel({
    required ChatStorageService storage,
    required ChatService chatService,
    required String characterId,
  })  : _storage = storage,
        _chatService = chatService,
        _characterId = characterId;

  ChatCharacter? get character => _character;
  List<ChatMessage> get messages => _messages;
  String get inputText => _inputText;
  bool get isLoading => _loading;
  bool get isSending => _sending;
  String get streamingContent => _streamingContent;

  void setInputText(String v) {
    _inputText = v;
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _character = await _storage.loadCharacter(_characterId);
    _messages = await _storage.loadMessages(_characterId);
    _loading = false;
    notifyListeners();
  }

  Future<void> sendMessage() async {
    final text = _inputText.trim();
    if (text.isEmpty || _sending || _character == null) return;

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: text,
    );
    _messages.add(userMsg);
    await _storage.appendMessage(_characterId, userMsg);
    _inputText = '';
    _sending = true;
    _streamingContent = '';
    notifyListeners();

    // 不包括刚发的这条，由 ChatService 拼到最后
    final historyMessages = _messages.length > 20
        ? _messages.sublist(_messages.length - 20, _messages.length - 1)
        : _messages.sublist(0, _messages.length - 1);

      _streamSub = _chatService
        .sendMessage(
          character: _character!,
          recentMessages: historyMessages,
          userInput: text,
        )
        .listen(
          (chunk) {
            _streamingContent += chunk;
            notifyListeners();
          },
          onDone: () async {
            final assistantMsg = ChatMessage(
              id: const Uuid().v4(),
              role: 'assistant',
              content: _streamingContent,
            );
            _messages.add(assistantMsg);
            await _storage.appendMessage(_characterId, assistantMsg);
            if (_character != null) {
              _character!.lastActiveAt = DateTime.now();
              await _storage.saveCharacter(_character!);
            }
            _sending = false;
            _streamingContent = '';
            notifyListeners();
          },
          onError: (e) {
            _sending = false;
            _streamingContent = '';
            notifyListeners();
            debugPrint('[Chat] 流式错误: $e');
          },
        );
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}
