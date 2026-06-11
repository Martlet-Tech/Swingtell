import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/news_summary_record.dart';
import '../../core/services/news_storage_service.dart';
import 'news_summary_screen.dart';

class NewsSummaryHistoryScreen extends StatefulWidget {
  final String topicId;
  final String topicName;

  const NewsSummaryHistoryScreen({
    super.key,
    required this.topicId,
    required this.topicName,
  });

  @override
  State<NewsSummaryHistoryScreen> createState() =>
      _NewsSummaryHistoryScreenState();
}

class _NewsSummaryHistoryScreenState extends State<NewsSummaryHistoryScreen> {
  List<NewsSummaryRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = context.read<NewsStorageService>();
    final records = await storage.getRecordsForTopic(widget.topicId);
    if (mounted) {
      setState(() {
        _records = records;
        _loading = false;
      });
    }
  }

  void _openRecord(NewsSummaryRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsSummaryScreen(
          topicName: '${record.topicName} - ${record.timeRange}',
          topicPrompt: '',
          savedHtml: record.htmlContent,
          savedPlainText: record.plainText,
        ),
      ),
    );
  }

  Future<void> _deleteRecord(NewsSummaryRecord record) async {
    final storage = context.read<NewsStorageService>();
    await storage.deleteRecord(record.id);
    setState(() => _records.removeWhere((r) => r.id == record.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.topicName} - 历史')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(
                  child: Text(
                    '暂无历史记录\n点击 12h/24h/48h/周 生成总结后自动保存',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final r = _records[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: _timeRangeIcon(r.timeRange),
                        title: Text(
                          r.timeRange,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _formatDate(r.createdAt),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _deleteRecord(r),
                        ),
                        onTap: () => _openRecord(r),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _timeRangeIcon(String timeRange) {
    IconData icon;
    switch (timeRange) {
      case '12h':
        icon = Icons.hourglass_top;
        break;
      case '24h':
        icon = Icons.hourglass_bottom;
        break;
      case '48h':
        icon = Icons.timer;
        break;
      default:
        icon = Icons.date_range;
    }
    return CircleAvatar(
      radius: 18,
      child: Icon(icon, size: 20),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
