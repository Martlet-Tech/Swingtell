import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/timeline_service.dart';
import '../../core/services/tts/tts_pipeline.dart';
import 'timeline_viewmodel.dart';
import 'timeline_setup_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late TimelineViewModel _vm;
  bool _ttsPlaying = false;
  StreamSubscription<TtsState>? _ttsSub;

  @override
  void initState() {
    super.initState();
    _vm = TimelineViewModel(
      service: context.read<TimelineService>(),
      tts: context.read<TtsPipeline>(),
    );
    _listenTts();
    if (_vm.isConfigured) {
      _vm.load();
    }
  }

  @override
  void dispose() {
    _ttsSub?.cancel();
    _vm.dispose();
    super.dispose();
  }

  void _listenTts() {
    _ttsSub = _vm.ttsStateStream.listen((state) {
      if (mounted) setState(() => _ttsPlaying = state.isPlaying);
    });
  }

  Future<void> _setup() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TimelineSetupScreen(vm: _vm),
      ),
    );
    if (result == true && mounted) {
      _vm.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (!_vm.isConfigured) {
          return Scaffold(
            appBar: AppBar(title: const Text('世界线')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    '尚未设定世界线锚点',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('设定'),
                    onPressed: _setup,
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('世界线'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _setup,
                tooltip: '修改锚点',
              ),
            ],
          ),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _vm.error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _vm.error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildDateHeader(),
                        const SizedBox(height: 24),
                        _buildBriefing(),
                        if (_vm.entry != null &&
                            _vm.entry!.rawEvents.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildRawEvents(),
                        ],
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildDateHeader() {
    final today = _vm.todayInTimeline;
    if (today == null) return const SizedBox.shrink();
    return Column(
      children: [
        const Text(
          '你的世界线',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          '${today.year}年${today.month}月${today.day}日',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '（现实 ${_formatDate(DateTime.now())}）',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBriefing() {
    if (_vm.entry == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '今日简报',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _ttsPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    size: 32,
                  ),
                  onPressed: _vm.readAloud,
                  tooltip: _ttsPlaying ? '暂停' : '朗读简报',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _vm.entry!.briefing,
              style: const TextStyle(
                fontSize: 16,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawEvents() {
    return ExpansionTile(
      title: const Text(
        '历史原始事件',
        style: TextStyle(fontSize: 15),
      ),
      children: _vm.entry!.rawEvents.map((e) {
        return ListTile(
          dense: true,
          title: Text(e, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}年${dt.month}月${dt.day}日';
}
