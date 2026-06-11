import 'package:flutter/material.dart';
import '../../core/services/rss_service.dart';
import 'news_list_viewmodel.dart';

class NewsSettingsScreen extends StatefulWidget {
  final NewsListViewModel vm;
  const NewsSettingsScreen({super.key, required this.vm});

  @override
  State<NewsSettingsScreen> createState() => _NewsSettingsScreenState();
}

class _NewsSettingsScreenState extends State<NewsSettingsScreen> {
  final _promptCtrl = TextEditingController();
  late NewsListViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = widget.vm;
    _promptCtrl.text = _vm.globalPrompt ?? '';
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新闻设置'),
        actions: [
          TextButton(
            onPressed: () {
              _vm.setGlobalPrompt(_promptCtrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('联网搜索'),
            subtitle: const Text(
              '开启后请求中会附加联网搜索参数（取决于 API 提供商是否支持）',
              style: TextStyle(fontSize: 13),
            ),
            value: _vm.webSearchEnabled,
            onChanged: _vm.setWebSearchEnabled,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RSS 新闻源',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('恢复默认'),
                    onPressed: _vm.resetRssSources,
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加'),
                    onPressed: () => _addRssSource(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._vm.rssSources.map((source) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(source.name, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              source.url,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => _vm.removeRssSource(source),
            ),
          )),
          const Divider(height: 32),
          const Text(
            '全局风格提示词',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '如：用轻松幽默的语气、多用流行梗…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
              _vm.setGlobalPrompt(_promptCtrl.text.trim());
                Navigator.pop(context);
              },
              child: const Text('保存设置'),
            ),
          ),
        ],
      ),
    );
  }

  void _addRssSource(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (ctx) => AlertDialog(
        title: const Text('添加 RSS 源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '如：36氪',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'RSS 链接',
                hintText: 'https://example.com/feed.xml',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (name.isEmpty || url.isEmpty) return;
              Navigator.pop(ctx);
              _vm.addRssSource(RssSource(name, url));
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
