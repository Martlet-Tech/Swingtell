import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reader_provider.dart';
import '../../utils/constants.dart';
import '../settings/tts_settings_sheet.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderPage({super.key, required this.bookId});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewKey = GlobalKey(debugLabel: 'scrollView');
  List<GlobalKey> _sentenceKeys = [];
  int _lastScrolledIndex = -1;
  bool _isAutoScrolling = false;
  bool _needsRestore = true;
  late final ReaderNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(readerProvider(widget.bookId).notifier);
    Future.microtask(() async {
      await _notifier.loadBook();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryRestore());
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Scroll helpers
  // ---------------------------------------------------------------------------

  void _scrollToSentence(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _sentenceKeys.length) return;
      final ctx = _sentenceKeys[index].currentContext;
      if (ctx != null) {
        _isAutoScrolling = true;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.3,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _tryRestore() {
    if (!_needsRestore) return;
    _needsRestore = false;
    final st = ref.read(readerProvider(widget.bookId));
    if (st.sentences.isEmpty || st.currentSentenceIndex >= _sentenceKeys.length) return;
    _scrollToSentence(st.currentSentenceIndex);
  }

  // ---------------------------------------------------------------------------
  // Scroll notifications
  // ---------------------------------------------------------------------------

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isAutoScrolling) {
      if (notification is ScrollEndNotification) {
        _isAutoScrolling = false;
      }
      return false;
    }

    if (notification is ScrollStartNotification && notification.dragDetails != null) {
      if (ref.read(readerProvider(widget.bookId)).isPlaying) {
        _notifier.pause();
      }
    } else if (notification is ScrollEndNotification && notification.dragDetails != null) {
      _findNearestVisibleSentence();
    }
    return false;
  }

  void _findNearestVisibleSentence() {
    final rs = ref.read(readerProvider(widget.bookId));
    if (rs.sentences.isEmpty) return;

    final scrollBox = _scrollViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollBox == null || !scrollBox.hasSize) return;

    final viewportHeight = scrollBox.size.height;
    final targetY = viewportHeight * 0.35;

    int bestIdx = rs.currentSentenceIndex;
    double bestDist = double.infinity;

    for (int i = 0; i < rs.sentences.length; i++) {
      final ctx = _sentenceKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;

      try {
        final offset = box.localToGlobal(Offset.zero, ancestor: scrollBox);
        final dist = (offset.dy - targetY).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestIdx = i;
        }
      } catch (_) {
        continue;
      }
    }

    if (bestIdx != rs.currentSentenceIndex) {
      _notifier.seekToSentence(bestIdx);
    }
  }

  // ---------------------------------------------------------------------------
  // Sentence key management
  // ---------------------------------------------------------------------------

  void _syncSentenceKeys(int length) {
    if (_sentenceKeys.length != length) {
      _sentenceKeys = List.generate(length, (_) => GlobalKey(debugLabel: 'sent'));
    }
  }

  @override
  void dispose() {
    _notifier.pause();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerProvider(widget.bookId));

    // Auto-scroll when TTS advances to next sentence during playback.
    if (state.isPlaying && state.currentSentenceIndex != _lastScrolledIndex) {
      _lastScrolledIndex = state.currentSentenceIndex;
      _scrollToSentence(state.currentSentenceIndex);
    }

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
                await _notifier.jumpToChapter(idx);
                setState(() {
                  _sentenceKeys = [];
                  _lastScrolledIndex = -1;
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
    if (state.currentContent.isEmpty) {
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

    _syncSentenceKeys(state.sentences.length);

    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: SingleChildScrollView(
              key: _scrollViewKey,
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < state.sentences.length; i++)
                      _buildSentenceWidget(i, state),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildControlBar(state),
      ],
    );
  }

  static const double _baseFontSize = 18.0;

  Widget _buildSentenceWidget(int index, ReaderState st) {
    final isCurrent = index == st.currentSentenceIndex;
    final isPast = index < st.currentSentenceIndex;
    final isPlaying = st.isPlaying && isCurrent;
    final scale = st.sentenceScales[index];
    final isBlockStart = st.sentenceIsBlockStart[index];

    return Container(
      key: _sentenceKeys[index],
      margin: isBlockStart && index > 0
          ? const EdgeInsets.only(top: 20)
          : null,
      child: Text(
        st.sentences[index],
        style: TextStyle(
          fontSize: _baseFontSize * scale,
          fontWeight: scale > 1.0 ? FontWeight.w600 : null,
          height: 1.8,
          backgroundColor: isCurrent && isPlaying
              ? AppConstants.primaryColor.withValues(alpha: 0.3)
              : null,
          color: isPast
              ? Colors.grey.shade600
              : (isCurrent && isPlaying ? AppConstants.accentColor : null),
        ),
      ),
    );
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
                onTap: () => TtsSettingsSheet.show(
                  context,
                  onChanged: (speed, pitch) => _notifier.updateTtsSettings(speed, pitch),
                ),
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
                  _notifier.prevChapter();
                  setState(() {
                    _sentenceKeys = [];
                    _lastScrolledIndex = -1;
                    _needsRestore = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.replay_10),
                iconSize: 24,
                onPressed: _notifier.prevSentence,
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
                  onPressed: _notifier.togglePlayPause,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10),
                iconSize: 24,
                onPressed: _notifier.nextSentence,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 28,
                onPressed: () {
                  _notifier.nextChapter();
                  setState(() {
                    _sentenceKeys = [];
                    _lastScrolledIndex = -1;
                    _needsRestore = false;
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
