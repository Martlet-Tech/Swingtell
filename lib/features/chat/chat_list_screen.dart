import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/chat_storage_service.dart';
import '../../core/models/chat_character.dart';
import 'chat_list_viewmodel.dart';
import 'character_edit_screen.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late ChatListViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ChatListViewModel(context.read<ChatStorageService>());
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _createCharacter() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const CharacterEditScreen(),
      ),
    );
    if (result != null && mounted) {
      await _vm.createCharacter(result['name']!, result['prompt']!);
    }
  }

  Future<void> _editCharacter(ChatCharacter char) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterEditScreen(character: char),
      ),
    );
    if (result != null && mounted) {
      char.name = result['name']!;
      char.systemPrompt = result['prompt']!;
      await _vm.updateCharacter(char);
    }
  }

  void _onTapCharacter(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(characterId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('AI 聊天'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createCharacter,
                tooltip: '新建角色',
              ),
              IconButton(
                icon: const Icon(Icons.file_download),
                onPressed: _vm.importCharacter,
                tooltip: '导入',
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'export_all') {
                    final file = await _vm.exportAll();
                    if (file != null && mounted) {
                      await Share.shareXFiles([XFile(file.path)]);
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'export_all',
                    child: Text('导出全部'),
                  ),
                ],
              ),
            ],
          ),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _vm.characters.isEmpty
                  ? const Center(child: Text('还没有角色，点击 + 新建'))
                  : ListView.builder(
                      itemCount: _vm.characters.length,
                      itemBuilder: (context, index) {
                        final char = _vm.characters[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(char.name.isNotEmpty
                                ? char.name[0]
                                : '?'),
                          ),
                          title: Text(char.name),
                          subtitle: Text(
                            char.systemPrompt.isEmpty
                                ? '通用聊天助手'
                                : char.systemPrompt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            _formatDate(char.lastActiveAt),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          onTap: () => _onTapCharacter(char.id),
                          onLongPress: () => _showCharMenu(char),
                        );
                      },
                    ),
        );
      },
    );
  }

  void _showCharMenu(ChatCharacter char) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(ctx);
                _editCharacter(char);
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('导出'),
              onTap: () async {
                Navigator.pop(ctx);
                final file = await _vm.exportCharacter(char.id);
                if (file != null && mounted) {
                  await Share.shareXFiles([XFile(file.path)]);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _vm.deleteCharacter(char.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${dt.month}/${dt.day}';
  }
}
