import 'package:flutter/material.dart';

class TopicEditScreen extends StatefulWidget {
  final String? initialName;
  final String? initialPrompt;

  const TopicEditScreen({
    super.key,
    this.initialName,
    this.initialPrompt,
  });

  @override
  State<TopicEditScreen> createState() => _TopicEditScreenState();
}

class _TopicEditScreenState extends State<TopicEditScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _promptCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _promptCtrl = TextEditingController(text: widget.initialPrompt ?? '');
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
        const SnackBar(content: Text('请输入名称')),
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
    final isEdit = widget.initialName != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑关注点' : '新建关注点'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '如：美伊战争进展',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '关注点提示词',
              hintText: '描述你想关注的新闻方向，越具体越好…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
