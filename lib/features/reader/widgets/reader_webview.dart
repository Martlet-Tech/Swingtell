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
        onPageStarted: (_) => debugPrint('[WebView] onPageStarted'),
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
    await _injectTtsFeatures();
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
    final r = (theme.bg.r * 255).round().clamp(0, 255);
    final g = (theme.bg.g * 255).round().clamp(0, 255);
    final b = (theme.bg.b * 255).round().clamp(0, 255);
    await _controller.runJavaScript(
      "window.showTopMask(false, 'rgb($r,$g,$b)');",
    );
  }

  Future<void> _injectTtsFeatures() async {
    await _controller.runJavaScript('''
      (function() {
        var _hlEl = null;

        function findElement(anchor) {
          if (!anchor || anchor.length < 3) return null;
          var walker = document.createTreeWalker(
            document.body, NodeFilter.SHOW_TEXT, null
          );
          var node;
          while ((node = walker.nextNode())) {
            if (node.textContent.indexOf(anchor) !== -1) {
              return node.parentElement;
            }
          }
          return null;
        }

        window.highlightText = function(searchText) {
          var anchor = searchText.substring(0, Math.min(20, searchText.length));
          var el = findElement(anchor);
          if (!el) return;
          if (_hlEl && _hlEl !== el) {
            _hlEl.style.backgroundColor = '';
            _hlEl.style.borderRadius = '';
          }
          el.style.backgroundColor = 'rgba(255, 200, 50, 0.35)';
          el.style.borderRadius = '3px';
          _hlEl = el;
        };

        window.scrollToAnchor = function(searchText) {
          var anchor = searchText.substring(0, Math.min(20, searchText.length));
          var el = findElement(anchor);
          if (!el) return;
          var rect = el.getBoundingClientRect();
          var absoluteTop = rect.top + window.scrollY;
          var targetScrollY = absoluteTop - window.innerHeight * 0.25;
          targetScrollY = Math.max(0, targetScrollY);
          window.scrollTo({ top: targetScrollY, behavior: 'smooth' });
        };

        window.jumpToAnchor = function(searchText) {
          var anchor = searchText.substring(0, Math.min(20, searchText.length));
          var el = findElement(anchor);
          if (!el) return;
          var rect = el.getBoundingClientRect();
          var absoluteTop = rect.top + window.scrollY;
          var targetScrollY = absoluteTop - window.innerHeight * 0.25;
          targetScrollY = Math.max(0, targetScrollY);
          window.scrollTo({ top: targetScrollY, behavior: 'instant' });
        };

        window.clearHighlight = function() {
          if (_hlEl) {
            _hlEl.style.backgroundColor = '';
            _hlEl.style.borderRadius = '';
            _hlEl = null;
          }
        };

        window.getFirstVisibleText = function(topFraction) {
          topFraction = topFraction || 0.33;
          var targetY = window.scrollY + window.innerHeight * topFraction;
          var walker = document.createTreeWalker(
            document.body, NodeFilter.SHOW_TEXT, null
          );
          var node;
          while ((node = walker.nextNode())) {
            if (node.textContent.trim().length < 5) continue;
            var el = node.parentElement;
            if (!el) continue;
            var rect = el.getBoundingClientRect();
            var elTop = rect.top + window.scrollY;
            if (elTop >= targetY - 50) {
              return node.textContent.trim().substring(0, 30);
            }
          }
          return '';
        };

        var _mask = document.createElement('div');
        _mask.style.cssText = [
          'position:fixed', 'top:0', 'left:0', 'right:0',
          'height:28%', 'pointer-events:none', 'z-index:99', 'display:none'
        ].join(';');
        document.body.appendChild(_mask);

        window.showTopMask = function(visible, bgRgb) {
          if (bgRgb) {
            _mask.style.background =
              'linear-gradient(to bottom, ' + bgRgb + ' 50%, transparent 100%)';
          }
          _mask.style.display = visible ? 'block' : 'none';
        };

        var _scrollTimer = null;
        window.addEventListener('scroll', function() {
          if (_scrollTimer) clearTimeout(_scrollTimer);
          _scrollTimer = setTimeout(function() {
            _scrollTimer = null;
            var text = window.getFirstVisibleText(0.1);
            ScrollBridge.postMessage(text);
          }, 500);
        });
      })();
    ''');
  }

  // ── Public methods ─────────────────────────────────

  Future<void> updateStyle(ReaderSettings s) async {
    await _injectCss(s);
  }

  Future<void> highlightText(String text) async {
    if (text.isEmpty) return;
    final safe = text
        .substring(0, text.length > 20 ? 20 : text.length)
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', ' ');
    await _controller.runJavaScript(
      "window.highlightText('$safe');",
    );
  }

  Future<void> scrollToAnchor(String text) async {
    if (text.isEmpty) return;
    final safe = text
        .substring(0, text.length > 20 ? 20 : text.length)
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', ' ');
    await _controller.runJavaScript(
      "window.scrollToAnchor('$safe');",
    );
  }

  Future<void> jumpToAnchor(String text) async {
    if (text.isEmpty) return;
    final safe = text
        .substring(0, text.length > 20 ? 20 : text.length)
        .replaceAll('\\\\', '\\\\\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', ' ');
    await _controller.runJavaScript(
      "window.jumpToAnchor('$safe');",
    );
  }

  Future<void> clearHighlight() async {
    await _controller.runJavaScript('window.clearHighlight();');
  }

  Future<String> getFirstVisibleText({double topFraction = 0.33}) async {
    final result = await _controller.runJavaScriptReturningResult(
      'window.getFirstVisibleText($topFraction)',
    );
    return result.toString();
  }

  Future<void> showTopMask(bool visible, Color bgColor) async {
    final r = (bgColor.r * 255).round().clamp(0, 255);
    final g = (bgColor.g * 255).round().clamp(0, 255);
    final b = (bgColor.b * 255).round().clamp(0, 255);
    await _controller.runJavaScript(
      "window.showTopMask($visible, 'rgb($r,$g,$b)');",
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
