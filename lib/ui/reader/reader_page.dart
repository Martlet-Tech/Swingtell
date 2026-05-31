import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reader_provider.dart';
import '../../services/tts/device_tts.dart';
import '../../services/tts/tts_base.dart';
import '../../utils/constants.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderPage({super.key, required this.bookId});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final DeviceTts _tts = DeviceTts();
  bool _ttsReady = false;
  List<String> _sentences = [];
  int _currentSentenceIndex = 0;
  StreamSubscription<TtsEvent>? _ttsSubscription;

  @override
  void initState() {
    super.initState();
    _initTts();
    Future.microtask(() => ref.read(readerProvider(widget.bookId).notifier).loadBook());
  }

  Future<void> _initTts() async {
    try {
      await _tts.init();
      _ttsSubscription = _tts.events.listen((event) {
        if (event.type == TtsEventType.completed && mounted) {
          _onTtsComplete();
        }
      });
      if (mounted) setState(() => _ttsReady = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS 初始化失败: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  void _onTtsComplete() {
    final notifier = ref.read(readerProvider(widget.bookId).notifier);
    if (_currentSentenceIndex < _sentences.length - 1) {
      setState(() => _currentSentenceIndex++);
      _tts.speak(_sentences[_currentSentenceIndex]);
    } else {
      notifier.stop();
    }
  }

  void _speak(String text) {
    if (!_ttsReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TTS 未就绪'), backgroundColor: Colors.orange),
      );
      return;
    }
    _tts.speak(text);
    ref.read(readerProvider(widget.bookId).notifier).updateCharOffset(text.length);
  }

  void _togglePlayPause() {
    final notifier = ref.read(readerProvider(widget.bookId).notifier);
    final state = ref.read(readerProvider(widget.bookId));
    if (state.isPlaying) {
      _tts.stop();
      notifier.pause();
    } else if (state.isPaused) {
      // flutter_tts 4.x has no resume; stop + re-speak
      if (_currentSentenceIndex < _sentences.length) {
        _speak(_sentences[_currentSentenceIndex]);
      }
      notifier.play();
    } else {
      final content = state.currentContent;
      if (content.isNotEmpty) {
        _sentences = _splitSentences(content);
        _currentSentenceIndex = 0;
        _speak(_sentences.first);
        notifier.play();
      }
    }
  }

  List<String> _splitSentences(String text) {
    if (text.isEmpty) return [];
    final parts = text.split(RegExp(r'(?<=[。！？\n])'));
    return parts.where((s) => s.trim().isNotEmpty).toList();
  }

  void _nextSentence() {
    final notifier = ref.read(readerProvider(widget.bookId).notifier);
    if (_currentSentenceIndex < _sentences.length - 1) {
      setState(() => _currentSentenceIndex++);
      _speak(_sentences[_currentSentenceIndex]);
      notifier.play();
    }
  }

  void _prevSentence() {
    if (_currentSentenceIndex > 0) {
      setState(() => _currentSentenceIndex--);
      _speak(_sentences[_currentSentenceIndex]);
    }
  }

  @override
  void dispose() {
    _ttsSubscription?.cancel();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerProvider(widget.bookId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.book?.title ?? '阅读',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (state.chapters.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: '章节列表',
              onSelected: (idx) async {
                await ref.read(readerProvider(widget.bookId).notifier).jumpToChapter(idx);
                setState(() {
                  _sentences = [];
                  _currentSentenceIndex = 0;
                });
              },
              itemBuilder: (_) => state.chapters.map((ch) {
                final isCurrent = ch.index == state.currentChapterIndex;
                return PopupMenuItem(
                  value: ch.index,
                  child: Row(
                    children: [
                      if (isCurrent) const Icon(Icons.play_arrow, size: 18),
                      if (isCurrent) const SizedBox(width: 8),
                      Text(ch.title, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : null)),
                    ],
                  ),
                );
              }).toList(),
              icon: const Icon(Icons.list),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('加载失败: ${state.error}', style: TextStyle(color: Colors.red.shade300)))
              : _buildReader(state),
    );
  }

  Widget _buildReader(ReaderState state) {
    final content = state.currentContent;
    if (content.isEmpty) {
      final href = state.chapters.isNotEmpty && state.currentChapterIndex < state.chapters.length
          ? state.chapters[state.currentChapterIndex].title
          : '?';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('暂无内容', style: TextStyle(color: Colors.grey.shade400, fontSize: 18)),
              const SizedBox(height: 12),
              Text('文件: ${state.book?.filePath ?? "?"}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Text('章节: ${state.currentChapterIndex + 1}/${state.chapters.length}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Text('标题: $href', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 16),
              Text('压缩包文件:', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              const SizedBox(height: 4),
              _DebugArchiveList(filePath: state.book?.filePath ?? ''),
            ],
          ),
        ),
      );
    }

    if (_sentences.isEmpty && content.isNotEmpty) {
      _sentences = _splitSentences(content);
    }

    return Column(
      children: [
        // Text display area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText.rich(
              _buildStyledText(state),
              style: const TextStyle(fontSize: _baseFontSize, height: 1.8),
            ),
          ),
        ),

        // Control bar
        _buildControlBar(state),
      ],
    );
  }

  static const double _baseFontSize = 18.0;

  /// Build rich text by rendering blocks directly with per-block scale,
  /// aligning sentence indices with TTS for highlighting.
  TextSpan _buildStyledText(ReaderState state) {
    if (state.currentBlocks.isEmpty) {
      if (_sentences.isEmpty) return const TextSpan(text: '');
      return TextSpan(text: _sentences.join(''));
    }

    final spans = <InlineSpan>[];
    var sentIdx = 0; // maps to _currentSentenceIndex

    for (int b = 0; b < state.currentBlocks.length; b++) {
      final block = state.currentBlocks[b];
      if (block.text.isEmpty) continue;

      // Blank line between blocks for paragraph spacing
      if (b > 0) {
        spans.add(const TextSpan(text: '\n'));
      }

      // Split the block text into sentences so we can highlight the right one
      final blockSentences = _splitSentences(block.text);

      if (blockSentences.isEmpty) {
        // Block with no sentence breaks — render whole block
        spans.add(TextSpan(
          text: block.text,
          style: TextStyle(
            fontSize: _baseFontSize * block.scale,
            fontWeight: block.scale > 1.0 ? FontWeight.w600 : null,
          ),
        ));
      } else {
        for (final sentence in blockSentences) {
          final isHighlighted = sentIdx == _currentSentenceIndex && state.isPlaying;
          spans.add(TextSpan(
            text: sentence,
            style: TextStyle(
              fontSize: _baseFontSize * block.scale,
              fontWeight: block.scale > 1.0 ? FontWeight.w600 : null,
              backgroundColor: isHighlighted
                  ? AppConstants.primaryColor.withValues(alpha: 0.3)
                  : null,
              color: sentIdx < _currentSentenceIndex
                  ? Colors.grey.shade600
                  : (isHighlighted ? AppConstants.accentColor : null),
            ),
          ));
          sentIdx++;
        }
      }
    }

    return TextSpan(children: spans);
  }

  Widget _buildControlBar(ReaderState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade800, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chapter title
          if (state.chapters.isNotEmpty && state.currentChapterIndex < state.chapters.length)
            Text(
              state.chapters[state.currentChapterIndex].title,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),

          // Progress slider
          Slider(
            value: state.totalProgress,
            onChanged: (v) {},
            min: 0.0,
            max: 1.0,
          ),

          // Time + speed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(state.totalProgress * 100).toInt()}%',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              GestureDetector(
                onTap: () {
                  final speeds = AppConstants.presetSpeeds;
                  final currentIdx = speeds.indexOf(state.speed);
                  final nextIdx = (currentIdx + 1) % speeds.length;
                  final newSpeed = speeds[nextIdx];
                  _tts.setSpeed(newSpeed);
                  ref.read(readerProvider(widget.bookId).notifier).setSpeed(newSpeed);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade600),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${state.speed}x', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Playback buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 28,
                onPressed: () {
                  ref.read(readerProvider(widget.bookId).notifier).prevChapter();
                  setState(() {
                    _sentences = [];
                    _currentSentenceIndex = 0;
                  });
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.replay_10),
                iconSize: 24,
                onPressed: _prevSentence,
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 36,
                  color: Colors.white,
                  onPressed: _togglePlayPause,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10),
                iconSize: 24,
                onPressed: _nextSentence,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 28,
                onPressed: () {
                  ref.read(readerProvider(widget.bookId).notifier).nextChapter();
                  setState(() {
                    _sentences = [];
                    _currentSentenceIndex = 0;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugArchiveList extends StatefulWidget {
  final String filePath;
  const _DebugArchiveList({required this.filePath});

  @override
  State<_DebugArchiveList> createState() => _DebugArchiveListState();
}

class _DebugArchiveListState extends State<_DebugArchiveList> {
  String _info = '加载中...';

  @override
  void initState() {
    super.initState();
    _loadArchiveInfo();
  }

  Future<void> _loadArchiveInfo() async {
    if (widget.filePath.isEmpty || !File(widget.filePath).existsSync()) {
      setState(() => _info = '文件不存在');
      return;
    }
    try {
      final data = await File(widget.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(data);
      final buf = StringBuffer();
      buf.writeln('压缩包文件数: ${archive.files.length}');
      buf.writeln('--- 前30个文件 ---');
      for (final f in archive.files.take(30)) {
        buf.writeln('  ${f.name} (${f.size} bytes)');
      }
      setState(() => _info = buf.toString());
    } catch (e) {
      setState(() => _info = '读取失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: SingleChildScrollView(
        child: SelectableText(
          _info,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
