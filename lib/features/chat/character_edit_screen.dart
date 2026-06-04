import 'package:flutter/material.dart';
import '../../core/models/chat_character.dart';

class CharacterEditScreen extends StatefulWidget {
  final ChatCharacter? character;
  const CharacterEditScreen({super.key, this.character});

  @override
  State<CharacterEditScreen> createState() => _CharacterEditScreenState();
}

class _CharacterEditScreenState extends State<CharacterEditScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _promptCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.character?.name ?? '');
    _promptCtrl = TextEditingController(text: widget.character?.systemPrompt ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入角色名')),
      );
      return;
    }
    Navigator.pop(context, {
      'name': name,
      'prompt': _promptCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.character != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑角色' : '新建角色'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              child: Text(
                _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : '?',
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '角色名',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '系统提示词',
              hintText: '描述角色的性格、身份、说话风格…\n留空则为通用聊天助手',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
