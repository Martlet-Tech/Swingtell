import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    _vm.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vm.onAppPause();
    _vm.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _vm.onAppPause();
    }
  }

  void _toggleBars() {
    setState(() => _barsVisible = !_barsVisible);
  }

  void _onBack() {
    _vm.onAppPause();
    Navigator.pop(context);
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ChapterListSheet(
        titles: _vm.chapterTitles,
        currentIndex: _vm.currentChapterIndex,
        onTap: _vm.goToChapter,
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

  void _toggleReadingMode() {
    final mode = _vm.settings.readingMode == 'scroll' ? 'page' : 'scroll';
    _settingsService.update(_vm.settings.copyWith(readingMode: mode));
  }

  void _showTtsSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const TtsSettingsPanel(),
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

        return Scaffold(
          backgroundColor: theme.bg,
          body: Stack(
            children: [
              ReaderWebview(
                chapterHtml: html,
                initialScrollOffset: _vm.initialScrollOffset,
                settings: _vm.settings,
                onScroll: _vm.onScroll,
              ),
              GestureLayer(
                readingMode: _vm.settings.readingMode,
                onTapCenter: _toggleBars,
              ),
              Positioned(
                top: 0, left: 0, right: 0,
                child: AnimatedSlide(
                  offset: _barsVisible ? Offset.zero : const Offset(0, -1),
                  duration: const Duration(milliseconds: 200),
                  child: ReaderTopBar(
                    title: _vm.book.title,
                    settings: _vm.settings,
                    onBack: _onBack,
                    onTtsPlay: _vm.toggleTts,
                    onTtsSettings: _showTtsSettings,
                    isTtsPlaying: _vm.isTtsPlaying,
                  ),
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedSlide(
                  offset: _barsVisible ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 200),
                    child: ReaderBottomBar(
                    settings: _vm.settings,
                    onChapterList: _showChapterList,
                    onColorTheme: _showColorTheme,
                    onFontSettings: _showFontSettings,
                    onReadingModeToggle: _toggleReadingMode,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
