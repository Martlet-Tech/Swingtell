import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/models/reader_settings.dart';
import '../../../core/constants/app_constants.dart';

class ReaderWebview extends StatefulWidget {
  final String chapterHtml;
  final ReaderSettings settings;
  final void Function(String visibleText) onScroll;
  final VoidCallback? onPageReady;

  const ReaderWebview({
    super.key,
    required this.chapterHtml,
    required this.settings,
    required this.onScroll,
    this.onPageReady,
  });

  @override
  State<ReaderWebview> createState() => ReaderWebviewState();
}

class ReaderWebviewState extends State<ReaderWebview> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ScrollBridge',
        onMessageReceived: (msg) {
          widget.onScroll(msg.message);
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _onPageReady(),
      ));
    _controller.loadHtmlString(widget.chapterHtml);
  }

  @override
  void didUpdateWidget(ReaderWebview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterHtml != widget.chapterHtml) {
      _controller.loadHtmlString(widget.chapterHtml);
    } else {
      _injectCss(widget.settings);
    }
  }

  Future<void> _onPageReady() async {
    await _injectCss(widget.settings);
    await _injectScrollListener();
    await _injectLyricSupport();
    widget.onPageReady?.call();
  }

  Future<void> _injectCss(ReaderSettings s) async {
    final theme = kColorThemes[s.colorThemeIndex];
    final css = '''
      body {
        font-family: ${s.fontFamily}, serif;
        font-size: ${s.fontSize}px;
        line-height: ${s.lineHeight};
        color: #${theme.text.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)};
        background-color: #${theme.bg.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)};
        margin: 16px 20px;
        word-break: break-all;
      }
      img { max-width: 100%; height: auto; }
      p { margin: 0 0 1em 0; }
    ''';
    await _controller.runJavaScript(
      "document.getElementById('reader-style').textContent = `$css`;",
    );
    await _updateTopMaskBg(s);
  }

  Future<void> _injectScrollListener() async {
    await _controller.runJavaScript('''
      (function() {
        var timer = null;
        window.addEventListener('scroll', function() {
          if (window._ttsScrolling) return;
          if (timer) return;
          timer = setTimeout(function() {
            timer = null;
            var text = typeof window.getFirstVisibleText === 'function'
              ? window.getFirstVisibleText() : '';
            ScrollBridge.postMessage(text);
          }, 500);
        });
      })();
    ''');
  }

  Future<void> _injectLyricSupport() async {
    await _controller.runJavaScript('''
      (function() {
        window._ttsScrolling = false;
        document.addEventListener('pointerdown', function() {
          window._ttsScrolling = false;
        });

        var mask = document.createElement('div');
        mask.id = 'top-mask';
        mask.style.cssText = [
          'position: fixed',
          'top: 0', 'left: 0', 'right: 0',
          'height: 28%',
          'pointer-events: none',
          'z-index: 99',
          'display: none',
          'background: linear-gradient(to bottom, rgb(248,243,232) 50%, transparent 100%)',
        ].join(';');
        document.body.appendChild(mask);
        document.documentElement.style.setProperty('--bg', 'rgb(248,243,232)');

        window.setLyricMode = function(active, bgColorRgb) {
          var el = document.getElementById('top-mask');
          if (!el) return;
          el.style.display = active ? 'block' : 'none';
          if (bgColorRgb) {
            document.documentElement.style.setProperty('--bg', bgColorRgb);
            el.style.background =
              'linear-gradient(to bottom, ' + bgColorRgb + ' 50%, transparent 100%)';
          }
        };

        var _hlEl = null;
        var _previewEl = null;

        window.trackReadingUnit = function(searchText, lyricMode) {
          if (!searchText || searchText.length < 3) return;
          var anchor = searchText.substring(0, Math.min(20, searchText.length));
          var walker = document.createTreeWalker(
            document.body, NodeFilter.SHOW_TEXT, null, false
          );
          var targetEl = null, node;
          while ((node = walker.nextNode())) {
            if (node.textContent.indexOf(anchor) !== -1) {
              targetEl = node.parentElement;
              break;
            }
          }
          if (!targetEl) return;

          if (_hlEl && _hlEl !== targetEl) {
            _hlEl.style.backgroundColor = '';
            _hlEl.style.borderRadius = '';
          }
          if (_previewEl) {
            _previewEl.style.backgroundColor = '';
            _previewEl.style.borderRadius = '';
            _previewEl = null;
          }
          targetEl.style.backgroundColor = 'rgba(255, 200, 50, 0.35)';
          targetEl.style.borderRadius = '3px';
          _hlEl = targetEl;

          if (lyricMode) {
            window._ttsScrolling = true;
            var absTop = targetEl.getBoundingClientRect().top + window.scrollY;
            var targetY = Math.max(0, absTop - window.innerHeight * 0.25);
            window.scrollTo({ top: targetY, behavior: 'smooth' });
            setTimeout(function() {
              if (window._ttsScrolling) window._ttsScrolling = false;
            }, 600);
          }
        };

        window.clearHighlight = function() {
          if (_hlEl) {
            _hlEl.style.backgroundColor = '';
            _hlEl.style.borderRadius = '';
            _hlEl = null;
          }
          window.clearPreview();
          window.setLyricMode(false);
        };

        window.previewReadingUnit = function(searchText) {
          if (!searchText || searchText.length < 3) return;
          var anchor = searchText.substring(0, Math.min(20, searchText.length));
          var walker = document.createTreeWalker(
            document.body, NodeFilter.SHOW_TEXT, null, false
          );
          var targetEl = null, node;
          while ((node = walker.nextNode())) {
            if (node.textContent.indexOf(anchor) !== -1) {
              targetEl = node.parentElement;
              break;
            }
          }
          if (!targetEl) return;

          if (_previewEl && _previewEl !== targetEl) {
            _previewEl.style.backgroundColor = '';
            _previewEl.style.borderRadius = '';
          }
          if (targetEl !== _hlEl) {
            targetEl.style.backgroundColor = 'rgba(255, 200, 50, 0.15)';
            targetEl.style.borderRadius = '3px';
          }
          _previewEl = targetEl;
        };

        window.clearPreview = function() {
          if (_previewEl) {
            _previewEl.style.backgroundColor = '';
            _previewEl.style.borderRadius = '';
            _previewEl = null;
          }
        };

        window.getFirstVisibleText = function() {
          var walker = document.createTreeWalker(
            document.body, NodeFilter.SHOW_TEXT, null, false
          );
          var node;
          while ((node = walker.nextNode())) {
            var rect = node.parentElement.getBoundingClientRect();
            if (rect.top >= 0 && rect.top < window.innerHeight * 0.4) {
              var t = (node.textContent || '').trim();
              if (t.length > 5) return t.substring(0, 30);
            }
          }
          return '';
        };
      })();
    ''');
  }

  Future<void> _updateTopMaskBg(ReaderSettings s) async {
    final theme = kColorThemes[s.colorThemeIndex];
    final r = (theme.bg.r * 255).round().clamp(0, 255);
    final g = (theme.bg.g * 255).round().clamp(0, 255);
    final b = (theme.bg.b * 255).round().clamp(0, 255);
    await _controller.runJavaScript(
      "window.setLyricMode(false, 'rgb($r,$g,$b)');",
    );
  }

  // ── Public methods ─────────────────────────────────

  Future<void> updateStyle(ReaderSettings s) async {
    await _injectCss(s);
  }

  Future<void> scrollToText(String text) async {
    if (text.isEmpty) return;
    final safe = text
        .substring(0, text.length > 20 ? 20 : text.length)
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', ' ');
    await _controller.runJavaScript('''
      (function() {
        var anchor = '$safe';
        var walker = document.createTreeWalker(
          document.body, NodeFilter.SHOW_TEXT, null, false
        );
        var node;
        while ((node = walker.nextNode())) {
          if (node.textContent.indexOf(anchor) !== -1) {
            var rect = node.parentElement.getBoundingClientRect();
            window.scrollTo(0, Math.max(0, rect.top + window.scrollY - window.innerHeight * 0.25));
            return;
          }
        }
      })();
    ''');
  }

  Future<void> trackReadingUnit(String text, {bool lyricMode = false}) async {
    if (text.isEmpty) return;
    final safe = text
        .substring(0, text.length > 20 ? 20 : text.length)
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', ' ');
    await _controller.runJavaScript(
      "window.trackReadingUnit('$safe', $lyricMode);",
    );
  }

  Future<void> setLyricMode(bool active) async {
    final theme = kColorThemes[widget.settings.colorThemeIndex];
    final r = (theme.bg.r * 255).round().clamp(0, 255);
    final g = (theme.bg.g * 255).round().clamp(0, 255);
    final b = (theme.bg.b * 255).round().clamp(0, 255);
    await _controller.runJavaScript(
      "window.setLyricMode($active, 'rgb($r,$g,$b)');",
    );
  }

  Future<void> clearHighlight() async {
    await _controller.runJavaScript('window.clearHighlight();');
  }

  Future<String> getFirstVisibleText() async {
    final result = await _controller.runJavaScriptReturningResult(
      'window.getFirstVisibleText()',
    );
    return result.toString();
  }

  Future<void> previewReadingUnit(String text) async {
    if (text.isEmpty) return;
    final safe = text
        .substring(0, text.length > 20 ? 20 : text.length)
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', ' ');
    await _controller.runJavaScript(
      "window.previewReadingUnit('$safe');",
    );
  }

  Future<void> clearPreview() async {
    await _controller.runJavaScript('window.clearPreview();');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
