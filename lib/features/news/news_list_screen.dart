import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/news_topic.dart';
import '../../core/services/news_storage_service.dart';
import 'news_list_viewmodel.dart';
import 'news_summary_screen.dart';
import 'news_summary_history_screen.dart';
import 'news_settings_screen.dart';
import 'topic_edit_screen.dart';

class NewsListScreen extends StatefulWidget {
  const NewsListScreen({super.key});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  late NewsListViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = NewsListViewModel(context.read<NewsStorageService>());
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _addTopic() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const TopicEditScreen()),
    );
    if (result != null && mounted) {
      await _vm.createTopic(result['name']!, result['prompt']!);
    }
  }

  Future<void> _editTopic(NewsTopic topic) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => TopicEditScreen(
          initialName: topic.name,
          initialPrompt: topic.prompt,
        ),
      ),
    );
    if (result != null && mounted) {
      topic.name = result['name']!;
      topic.prompt = result['prompt']!;
      await _vm.updateTopic(topic);
    }
  }

  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NewsSettingsScreen(vm: _vm)),
    );
  }

  void _onTopicTap(NewsTopic topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsSummaryHistoryScreen(
          topicId: topic.id,
          topicName: topic.name,
        ),
      ),
    );
  }

  void _onSummary(
      NewsTopic topic, String timeRange, String timeLabel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsSummaryScreen(
          topicId: topic.id,
          topicName: topic.name,
          topicPrompt: topic.prompt,
          timeRange: timeLabel,
          globalPrompt: _vm.globalPrompt,
          webSearchEnabled: _vm.webSearchEnabled,
        ),
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
            title: const Text('AI 新闻'),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _showSettings,
                tooltip: '设置',
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addTopic,
                tooltip: '新建关注点',
              ),
            ],
          ),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _vm.topics.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有关注点，点击 + 新建',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _vm.topics.length,
                      itemBuilder: (context, index) {
                        final topic = _vm.topics[index];
                        return _TopicCard(
                          topic: topic,
                          onTap: () => _onTopicTap(topic),
                          onEdit: () => _editTopic(topic),
                          onDelete: () => _vm.deleteTopic(topic.id),
                          onSummary: (timeRange, timeLabel) =>
                              _onSummary(topic, timeRange, timeLabel),
                        );
                      },
                    ),
        );
      },
    );
  }
}

class _TopicCard extends StatelessWidget {
  final NewsTopic topic;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String timeRange, String timeLabel) onSummary;

  const _TopicCard({
    required this.topic,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onSummary,
  });

  static const _timeButtons = [
    ('12h', '12小时'),
    ('24h', '24小时'),
    ('48h', '48小时'),
    ('week', '1周'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    topic.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (topic.prompt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                topic.prompt,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _timeButtons.map((b) {
                return ActionChip(
                  label: Text(b.$1),
                  onPressed: () => onSummary(b.$1, b.$2),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
