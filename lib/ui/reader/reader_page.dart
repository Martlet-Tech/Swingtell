import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reader_provider.dart';
import '../../providers/tts_player_provider.dart';
import '../../services/tts/tts_base.dart';
import '../../services/tts/tts_player.dart';
import '../../utils/app_logger.dart';
import '../../utils/constants.dart';
import '../settings/tts_settings_sheet.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderPage({super.key, required this.bookId});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _SentenceItem {
  final String text;
  final double scale;
  final bool isBlockStart;
  const _SentenceItem(this.text, this.scale, this.isBlockStart);
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  late final TtsPlayer _player;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewKey = GlobalKey(debugLabel: 'scrollView');
  List<String> _sentences = [];
  List<GlobalKey> _sentenceKeys = [];
  int _currentSentenceIndex = 0;
  bool _isAutoScrolling = false;
  bool _needsRestore = true;
  StreamSubscription<TtsPlaybackState>? _ttsStateSub;
  late final ReaderNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(readerProvider(widget.bookId).notifier);
    _player = ref.read(ttsPlayerProvider);
    _ttsStateSub = _player.state$.listen(_onPlayerStateChanged);
    Future.microtask(() async {
      await _notifier.loadBook();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryRestore());
      }
    });
  }

  void _onPlayerStateChanged(TtsPlaybackState playerState) {
    if (!mounted) return;
    final oldIndex = _currentSentenceIndex;
    setState(() {
      _currentSentenceIndex = playerState.currentIndex;
    });
    // Sync charOffset when TTS auto-advances during playback.
    if (playerState.isPlaying && playerState.currentIndex != oldIndex) {
      _syncCharOffsetFromIndex();
      _notifier.saveProgress();
      _scrollToCurrentSentence();
    }
    if (playerState.isCompleted) {
      _syncCharOffsetFromIndex();
      _notifier.saveProgress();
    }
  }

  void _scrollToCurrentSentence() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentSentenceIndex >= _sentenceKeys.length) return;
      final ctx = _sentenceKeys[_currentSentenceIndex].currentContext;
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

  void _pauseTts() async {
    await _player.pause();
    _notifier.pause();
    AppLogger.instance.info('TTS paused (user scroll) at sentence $_currentSentenceIndex');
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isAutoScrolling) {
      // Let programmatic scroll finish without triggering user-scroll logic
      if (notification is ScrollEndNotification) {
        _isAutoScrolling = false;
      }
      return false;
    }

    if (notification is ScrollStartNotification && notification.dragDetails != null) {
      if (_player.current.isPlaying) {
        _pauseTts();
      }
    } else if (notification is ScrollEndNotification && notification.dragDetails != null) {
      _findNearestVisibleSentence();
    }
    return false;
  }

  void _findNearestVisibleSentence() {
    if (_sentenceKeys.isEmpty) return;

    final scrollBox = _scrollViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollBox == null || !scrollBox.hasSize) return;

    final viewportHeight = scrollBox.size.height;
    final targetY = viewportHeight * 0.35;

    int bestIdx = _currentSentenceIndex;
    double bestDist = double.infinity;

    for (int i = 0; i < _sentenceKeys.length; i++) {
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

    if (bestIdx != _currentSentenceIndex) {
      setState(() => _currentSentenceIndex = bestIdx);
      _player.seekTo(bestIdx);
      _syncCharOffsetFromIndex();
    }
  }

  void _tryRestore() {
    if (!_needsRestore || _sentences.isEmpty) return;
    _needsRestore = false;
    final state = _notifier.state;
    if (state.charOffset <= 0) return;
    final targetIdx = _charOffsetToIndex(state.charOffset);
    if (targetIdx >= _sentenceKeys.length) return;
    if (_currentSentenceIndex != targetIdx) {
      setState(() => _currentSentenceIndex = targetIdx);
    }
    AppLogger.instance.info('Position restored: charOffset=${state.charOffset} → sentenceIdx=$targetIdx');
    final ctx = _sentenceKeys[targetIdx].currentContext;
    if (ctx != null) {
      _isAutoScrolling = true;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  int _charOffsetToIndex(int charOffset) {
    if (charOffset <= 0 || _sentences.isEmpty) return 0;
    var acc = 0;
    for (int i = 0; i < _sentences.length; i++) {
      acc += _sentences[i].length;
      if (acc > charOffset) return i;
    }
    return _sentences.length - 1;
  }

  void _syncCharOffsetFromIndex() {
    var offset = 0;
    for (int i = 0; i < _currentSentenceIndex && i < _sentences.length; i++) {
      offset += _sentences[i].length;
    }
    final oldOffset = _notifier.state.charOffset;
    _notifier.updateCharOffset(offset);
    if (oldOffset != offset) {
      AppLogger.instance.debug('Sync charOffset: $oldOffset→$offset (idx=$_currentSentenceIndex)');
    }
  }

  void _togglePlayPause() {
    final p = _player;
    final ps = p.current;
    if (ps.isPlaying) {
      p.pause();
      _notifier.pause();
    } else if (ps.isPaused || ps.isCompleted) {
      final state = _notifier.state;
      if (state.currentBlocks.isNotEmpty) {
        final items = _buildSentenceItems(state);
        _syncSentenceData(items);
        if (_sentences.isEmpty) return;
        if (ps.isCompleted) {
          p.loadSentences(_sentences);
        } else {
          p.seekTo(_currentSentenceIndex);
        }
        p.play();
        _scrollToCurrentSentence();
      }
    } else {
      final state = _notifier.state;
      if (state.currentBlocks.isNotEmpty) {
        final items = _buildSentenceItems(state);
        _syncSentenceData(items);
        if (_sentences.isEmpty) return;
        p.loadSentences(_sentences, startIndex: _currentSentenceIndex);
        p.play();
        _scrollToCurrentSentence();
      }
    }
  }

  List<String> _splitSentences(String text) {
    if (text.isEmpty) return [];
    final parts = text.split(RegExp(r'(?<=[。！？\n])'));
    return parts.where((s) => s.trim().isNotEmpty).toList();
  }

  void _nextSentence() {
    if (_currentSentenceIndex < _sentences.length - 1) {
      _player.next();
      _scrollToCurrentSentence();
    }
  }

  void _prevSentence() {
    if (_currentSentenceIndex > 0) {
      _player.previous();
      _scrollToCurrentSentence();
    }
  }

  @override
  void dispose() {
    _syncCharOffsetFromIndex(); // sync position from index before save
    final saved = _notifier.state;
    AppLogger.instance.info('Dispose save: chapter=${saved.currentChapterIndex}, charOffset=${saved.charOffset}, idx=$_currentSentenceIndex, totalProgress=${saved.totalProgress}');
    _notifier.pause(); // save progress
    _ttsStateSub?.cancel();
    // NOTE: _player is NOT disposed here — it lives in ttsPlayerProvider
    // and survives page navigation, enabling background playback later.
    _scrollController.dispose();
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
                await _notifier.jumpToChapter(idx);
                setState(() {
                  _sentences = [];
                  _sentenceKeys = [];
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

    final items = _buildSentenceItems(state);
    _syncSentenceData(items);

    // Set correct index during build so first frame renders with correct colors.
    // Actual scroll is deferred to _tryRestore via post-frame callback.
    if (_needsRestore && _sentences.isNotEmpty && state.charOffset > 0) {
      _currentSentenceIndex = _charOffsetToIndex(state.charOffset);
    }

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
                    for (int i = 0; i < items.length; i++)
                      _buildSentenceWidget(items[i], i, _player.current),
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

  List<_SentenceItem> _buildSentenceItems(ReaderState state) {
    final items = <_SentenceItem>[];
    for (final block in state.currentBlocks) {
      final sentStrs = _splitSentences(block.text);
      for (int i = 0; i < sentStrs.length; i++) {
        items.add(_SentenceItem(sentStrs[i], block.scale, i == 0));
      }
    }
    return items;
  }

  void _syncSentenceData(List<_SentenceItem> items) {
    if (_sentenceKeys.length != items.length) {
      _sentenceKeys = List.generate(items.length, (_) => GlobalKey(debugLabel: 'sent'));
      _sentences = items.map((e) => e.text).toList();
    }
  }

  Widget _buildSentenceWidget(_SentenceItem item, int index, TtsPlaybackState pstate) {
    final isCurrent = index == _currentSentenceIndex;
    final isPast = index < _currentSentenceIndex;
    final isPlaying = pstate.isPlaying && isCurrent;

    return Container(
      key: _sentenceKeys[index],
      margin: item.isBlockStart && index > 0
          ? const EdgeInsets.only(top: 20)
          : null,
      child: Text(
        item.text,
        style: TextStyle(
          fontSize: _baseFontSize * item.scale,
          fontWeight: item.scale > 1.0 ? FontWeight.w600 : null,
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
                  onChanged: (speed, pitch) {
                    _player.setSpeed(speed);
                    _player.setPitch(pitch);
                    _notifier.setSpeed(speed);
                    if (_player.current.isPlaying) {
                      _player.pause();
                      _player.play();
                    }
                  },
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
                    _sentences = [];
                    _sentenceKeys = [];
                    _currentSentenceIndex = 0;
                    _needsRestore = false;
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
                  icon: Icon(_player.current.isPlaying ? Icons.pause : Icons.play_arrow),
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
                  _notifier.nextChapter();
                  setState(() {
                    _sentences = [];
                    _sentenceKeys = [];
                    _currentSentenceIndex = 0;
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
