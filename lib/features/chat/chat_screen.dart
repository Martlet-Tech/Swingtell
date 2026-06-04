import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/chat_storage_service.dart';
import '../../core/services/chat_service.dart';
import 'chat_viewmodel.dart';
import 'widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String characterId;
  const ChatScreen({super.key, required this.characterId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatViewModel _vm;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _vm = ChatViewModel(
      storage: context.read<ChatStorageService>(),
      chatService: context.read<ChatService>(),
      characterId: widget.characterId,
    );
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _export() async {
    try {
      final file = await context.read<ChatStorageService>().exportCharacter(widget.characterId);
      if (mounted) {
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('加载中…')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(
                    _vm.character?.name.isNotEmpty == true
                        ? _vm.character!.name[0]
                        : '?',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_vm.character?.name ?? '聊天'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_upload),
                onPressed: _export,
                tooltip: '导出',
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _vm.messages.isEmpty && _vm.streamingContent.isEmpty
                    ? const Center(
                        child: Text(
                          '开始和 TA 聊天吧',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _vm.messages.length + (_vm.isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _vm.messages.length && _vm.isSending) {
                            return ChatBubble(
                              text: _vm.streamingContent.isEmpty
                                  ? '…'
                                  : _vm.streamingContent,
                              isUser: false,
                            );
                          }
                          final msg = _vm.messages[index];
                          return ChatBubble(
                            text: msg.content,
                            isUser: msg.role == 'user',
                            time: _formatTime(msg.createdAt),
                          );
                        },
                      ),
              ),
              if (_vm.isSending)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'AI 正在回复…',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 4,
                      color: Colors.black.withValues(alpha: 0.1),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: _vm.setInputText,
                          decoration: const InputDecoration(
                            hintText: '输入消息…',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _onSend(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _vm.isSending ? null : _onSend,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onSend() {
    _vm.sendMessage().then((_) => _scrollToBottom());
    _scrollToBottom();
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
