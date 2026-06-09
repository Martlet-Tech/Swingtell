import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/models/book.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/epub_service.dart';
import '../../core/services/progress_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/tts/tts_pipeline.dart';
import 'reader_viewmodel.dart';
import 'widgets/reader_webview.dart';
import 'widgets/reader_top_bar.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/chapter_list_sheet.dart';
import 'widgets/color_theme_popup.dart';
import 'widgets/font_settings_popup.dart';
import 'widgets/tts_settings_panel.dart';
import 'widgets/text_selection_popup.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;
  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  late ReaderViewModel _vm;
  late SettingsService _settingsService;
  final _webviewKey = GlobalKey<ReaderWebviewState>();
  bool _barsVisible = false;
  bool _showChapterPanel = false;

  // ── 文字选择 / AI 解释状态 ──
  bool _selectionMode = false;
  String _selectedText = '';
  double _selectionTop = 0;
  double _selectionLeft = 20;
  bool _showSelectionPopup = false;
  bool _explaining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsService = context.read<SettingsService>();
    _vm = ReaderViewModel(
      epubService: context.read<EpubService>(),
      progressService: context.read<ProgressService>(),
      settingsService: _settingsService,
      ttsPipeline: context.read<TtsPipeline>(),
      book: widget.book,
    );
    _vm.onTtsStateChanged = _onTtsStateChanged;
    _vm.onRestoreScroll = (text) {
      final webview = _webviewKey.currentState;
      webview?.jumpToAnchor(text);
      _vm.markProgrammaticScroll();
    };
    _vm.init();
    _syncWakelock();
    _settingsService.addListener(_syncWakelock);
  }

  @override
  void dispose() {
    _settingsService.removeListener(_syncWakelock);
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    _vm.onAppPause();
    _vm.dispose();
    super.dispose();
  }

  void _syncWakelock() {
    if (_settingsService.settings.keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _vm.onAppPause();
    }
  }

  void _onTtsStateChanged(TtsState state) {
    final webview = _webviewKey.currentState;
    final theme = kColorThemes[_vm.settings.colorThemeIndex];

    if (state.error != null && state.error!.isNotEmpty) {
      _showLLMErrorDialog(state.error!);
    }

    if (!state.isPlaying) {
      webview?.clearHighlight();
      webview?.showTopMask(false, theme.bg);
      return;
    }
    if (state.currentUnitText.isEmpty) return;

    webview?.showTopMask(true, theme.bg);

    if (_vm.scrollState == TtsScrollState.playing) {
      webview?.highlightText(state.currentUnitText);
      webview?.scrollToAnchor(state.currentUnitText);
      _vm.markProgrammaticScroll();
    }
  }

  Future<void> _onTtsPlay() async {
    final webview = _webviewKey.currentState;
    final theme = kColorThemes[_vm.settings.colorThemeIndex];

    if (_vm.isTtsPlaying) {
      _vm.toggleTts();
      webview?.showTopMask(false, theme.bg);
    } else if (_vm.ttsState.paragraphIndex > 0) {
      _vm.toggleTts();
    } else {
      final visibleText =
          await webview?.getFirstVisibleText(topFraction: 0.33) ?? '';
      await _vm.startTtsAt(visibleText);
    }
  }

  void _toggleBars() {
    setState(() => _barsVisible = !_barsVisible);
  }

  Future<void> _onBack() async {
    _exitSelectionMode();
    _vm.onAppPause();
    if (_vm.isTtsPlaying) {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('朗读中'),
          content: const Text('当前正在朗读，返回书架后是否继续朗读？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'stop'),
              child: const Text('停止朗读'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'continue'),
              child: const Text('继续朗读'),
            ),
          ],
        ),
      );
      if (result == 'stop') {
        await _vm.stopTts();
      } else if (result == 'cancel' || result == null) {
        return;
      }
    }
    if (mounted) Navigator.pop(context);
  }

  void _toggleChapterPanel() {
    setState(() => _showChapterPanel = !_showChapterPanel);
  }

  void _showColorTheme() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: ColorThemePopup(
          currentIndex: _vm.settings.colorThemeIndex,
          onSelected: (i) {
            _settingsService.update(_vm.settings.copyWith(colorThemeIndex: i));
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _showFontSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: FontSettingsPopup(
          settings: _vm.settings,
          onChanged: (updated) => _settingsService.update(updated),
        ),
      ),
    );
  }

  void _showTtsSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const TtsSettingsPanel(),
    );
  }

  void _onReturnToTts() {
    final webview = _webviewKey.currentState;
    if (webview == null) return;
    _vm.returnToTtsUnit();
    webview.highlightText(_vm.lastTtsUnitText);
    webview.scrollToAnchor(_vm.lastTtsUnitText);
    _vm.markProgrammaticScroll();
  }

  Future<void> _onStartTtsHere() async {
    final webview = _webviewKey.currentState;
    if (webview == null) return;
    _vm.startTtsHere();
    final visibleText = _vm.lastUserScrollText;
    if (visibleText.isEmpty) return;
    await _vm.seekTtsToVisibleText(visibleText);
  }

  void _showLLMErrorDialog(String errorMsg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 纠错失败'),
        content: Text(errorMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  // ── 文字选择 / AI 解释 ─────────────────────────────

  /// WebView SelectionBridge 回调
  void _onSelectionChanged(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'] as String?;
    if (type == 'clear') {
      setState(() {
        _showSelectionPopup = false;
        _selectedText = '';
      });
    } else if (type == 'selection') {
      final text = data['text'] as String? ?? '';
      final top = (data['top'] as num?)?.toDouble() ?? 0;
      final left = (data['left'] as num?)?.toDouble() ?? 20;
      if (text.isNotEmpty) {
        if (!_selectionMode) {
          if (_vm.isTtsPlaying) {
            _vm.toggleTts();
          }
          _selectionMode = true;
        }
        setState(() {
          _selectedText = text;
          _selectionTop = top;
          _selectionLeft = left;
          _showSelectionPopup = true;
        });
      }
    }
  }

  double _calculatePopupTop(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (_selectionTop < screenHeight * 0.4) {
      return (_selectionTop + 30).clamp(60.0, screenHeight - 160);
    } else {
      return (_selectionTop - 80).clamp(20.0, screenHeight - 160);
    }
  }

  /// 退出选择模式
  void _exitSelectionMode() {
    final webview = _webviewKey.currentState;
    webview?.clearSelection();
    setState(() {
      _selectionMode = false;
      _showSelectionPopup = false;
      _selectedText = '';
      _explaining = false;
    });
  }

  /// AI 解释：构建请求并调用 API
  Future<void> _onAiExplain() async {
    if (_selectedText.isEmpty) return;

    final webview = _webviewKey.currentState;
    if (webview == null) return;

    setState(() => _explaining = true);

    try {
      // 1. 从章节文本获取前一段落上下文（Dart 侧处理，JS 只做最轻量的事）
      final prevPara = _vm.getPreviousParagraph(_selectedText);

      // 2. 构建 Prompt
      final bookTitle = _vm.book.title;
      final chapterTitle = _vm.chapterTitles.isNotEmpty
          ? _vm.chapterTitles[_vm.currentChapterIndex]
          : '';

      final prompt = '''
你是专业的文学阅读助手。请结合上下文，解释用户选中的文字在书中的含义。

书籍：《$bookTitle》
${chapterTitle.isNotEmpty ? "章节：$chapterTitle" : ""}
${prevPara.isNotEmpty ? "上文（选中文字前的一段）：\n$prevPara\n" : ""}
选中文字：$_selectedText

请深入浅出地解释这段文字的含义，包括字面意思和深层含义。''';

      // 3. 调用 API
      final result = await _callExplanationApi(prompt);

      if (!mounted) return;

      // 4. 显示结果
      _exitSelectionMode();
      _showExplanationResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _explaining = false);
      _showLLMErrorDialog('请求失败: $e');
    }
  }

  /// 调用 OpenAI 兼容接口（非流式）
  Future<String> _callExplanationApi(String prompt) async {
    final settings = _settingsService.settings;
    if (settings.aiApiKey.isEmpty) {
      throw Exception('请先在设置页填写 API Key');
    }
    try {
      final request = http.Request('POST', Uri.parse('${settings.aiApiUrl}/chat/completions'));
      request.headers['Authorization'] = 'Bearer ${settings.aiApiKey}';
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': settings.aiModel,
        'messages': [
          {
            'role': 'system',
            'content': '你是一个专业的文学阅读助手。请用中文回答，解释简洁准确。',
          },
          {'role': 'user', 'content': prompt},
        ],
        'stream': false,
      });
      final streamedResponse = await http.Client().send(request);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200) {
        throw Exception('API 错误 ${response.statusCode}: ${response.body}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw Exception('API 返回为空');
      }
      final resultContent = choices[0]['message']['content'] as String? ?? '';
      return resultContent.trim();
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

  /// 展示 AI 解释结果
  void _showExplanationResult(String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome,
                size: 20, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('AI 解释'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 选中文字预览
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"$_selectedText"',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              // 解释内容
              SelectableText(
                content,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final html = _vm.currentHtml;
        if (html == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('无法加载书籍内容'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _onBack,
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          );
        }

        final theme = kColorThemes[_vm.settings.colorThemeIndex];

        return PopScope(
          canPop: !_vm.isTtsPlaying,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBack();
          },
          child: Scaffold(
            backgroundColor: theme.bg,
            body: Stack(
              children: [
                ReaderWebview(
                  key: _webviewKey,
                  chapterHtml: html,
                  settings: _vm.settings,
                  onScroll: _vm.onScrollSettled,
                  onPageReady: _vm.onPageReady,
                  onSelectionChanged: _onSelectionChanged,
                  onTapCenter: _toggleBars,
                  onDoubleTap: _onTtsPlay,
                ),


                // ── 文字选择浮动菜单 ──
                if (_showSelectionPopup && _selectedText.isNotEmpty)
                  Positioned(
                    top: _calculatePopupTop(context),
                    left: _selectionLeft.clamp(8.0,
                        MediaQuery.of(context).size.width - 200),
                    child: _explaining
                        ? const SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
                          )
                        : TextSelectionPopup(
                            selectedText: _selectedText,
                            onExplain: _onAiExplain,
                            onDismiss: _exitSelectionMode,
                          ),
                  ),

                // ── 浮动朗读按钮 ──
                if (_vm.showFloatButtons)
                  Positioned(
                    bottom: 80,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _FloatButton(
                          icon: Icons.keyboard_return,
                          label: '回到朗读处',
                          onTap: _onReturnToTts,
                        ),
                        const SizedBox(height: 8),
                        _FloatButton(
                          icon: Icons.play_arrow,
                          label: '在这开始读',
                          onTap: _onStartTtsHere,
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    offset:
                        _barsVisible ? Offset.zero : const Offset(0, -1),
                    duration: const Duration(milliseconds: 200),
                    child: ReaderTopBar(
                      bookTitle: _vm.book.title,
                      chapterTitle: _vm.chapterTitles.isNotEmpty
                          ? _vm.chapterTitles[_vm.currentChapterIndex]
                          : '',
                      onBack: _onBack,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    offset:
                        _barsVisible ? Offset.zero : const Offset(0, 1),
                    duration: const Duration(milliseconds: 200),
                    child: ReaderBottomBar(
                      onChapterList: _toggleChapterPanel,
                      onColorTheme: _showColorTheme,
                      onFontSettings: _showFontSettings,
                      onTtsPlay: _onTtsPlay,
                      onTtsSettings: _showTtsSettings,
                      isTtsPlaying: _vm.isTtsPlaying,
                    ),
                  ),
                ),
                // ── 章节目录面板 ──
                if (_showChapterPanel)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showChapterPanel = false),
                      child: Container(color: Colors.black26),
                    ),
                  ),
                if (_showChapterPanel)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom:
                        64 + MediaQuery.of(context).padding.bottom,
                    height:
                        MediaQuery.of(context).size.height * 0.5,
                    child: Material(
                      elevation: 8,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: ChapterListSheet(
                        titles: _vm.chapterTitles,
                        levels: _vm.chapterLevels,
                        currentIndex: _vm.currentChapterIndex,
                        onTap: (i) {
                          _vm.goToChapter(i, userInitiated: true);
                          setState(
                              () => _showChapterPanel = false);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FloatButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FloatButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
