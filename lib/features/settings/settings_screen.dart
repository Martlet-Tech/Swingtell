import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _keyCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _modelCtrl;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>().settings;
    _keyCtrl = TextEditingController(text: s.aiApiKey);
    _urlCtrl = TextEditingController(text: s.aiApiUrl);
    _modelCtrl = TextEditingController(text: s.aiModel);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.read<SettingsService>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'AI 对话',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyCtrl,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-...',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              settingsService.update(
                settingsService.settings.copyWith(aiApiKey: v),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'API URL',
              hintText: 'https://api.openai.com/v1',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              settingsService.update(
                settingsService.settings.copyWith(aiApiUrl: v),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: '模型',
              hintText: 'gpt-4o-mini',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              settingsService.update(
                settingsService.settings.copyWith(aiModel: v),
              );
            },
          ),
        ],
      ),
    );
  }
}
