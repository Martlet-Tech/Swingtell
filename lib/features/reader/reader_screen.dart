import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'widgets/gesture_layer.dart';
import 'widgets/chapter_list_sheet.dart';
import 'widgets/color_theme_popup.dart';
import 'widgets/font_settings_popup.dart';
import 'widgets/tts_settings_panel.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;
  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with WidgetsBindingObserver {
  late ReaderViewModel _vm;
  late SettingsService _settingsService;
  final _webviewKey = GlobalKey<ReaderWebviewState>();
  bool _barsVisible = false;

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
        return; // 取消，留在当前页
      }
      // result == 'continue': 保持 TTS 播放，返回书架
    }
    if (mounted) Navigator.pop(context);
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ChapterListSheet(
        titles: _vm.chapterTitles,
        currentIndex: _vm.currentChapterIndex,
          onTap: (i) => _vm.goToChapter(i, userInitiated: true),
      ),
    );
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
                ),
                GestureLayer(onTapCenter: _toggleBars),
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
                  top: 0, left: 0, right: 0,
                  child: AnimatedSlide(
                    offset: _barsVisible ? Offset.zero : const Offset(0, -1),
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
                  bottom: 0, left: 0, right: 0,
                  child: AnimatedSlide(
                    offset: _barsVisible ? Offset.zero : const Offset(0, 1),
                    duration: const Duration(milliseconds: 200),
                    child: ReaderBottomBar(
                      onChapterList: _showChapterList,
                      onColorTheme: _showColorTheme,
                      onFontSettings: _showFontSettings,
                      onTtsPlay: _onTtsPlay,
                      onTtsSettings: _showTtsSettings,
                      isTtsPlaying: _vm.isTtsPlaying,
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
