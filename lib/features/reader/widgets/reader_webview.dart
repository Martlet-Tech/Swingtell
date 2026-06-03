import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/models/reader_settings.dart';
import '../../../core/constants/app_constants.dart';

class ReaderWebview extends StatefulWidget {
  final String chapterHtml;
  final double initialScrollOffset;
  final ReaderSettings settings;
  final void Function(double scrollY, double pageHeight) onScroll;

  const ReaderWebview({
    super.key,
    required this.chapterHtml,
    required this.initialScrollOffset,
    required this.settings,
    required this.onScroll,
  });

  @override
  State<ReaderWebview> createState() => _ReaderWebviewState();
}

class _ReaderWebviewState extends State<ReaderWebview> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ScrollBridge',
        onMessageReceived: (msg) {
          final parts = msg.message.split(',');
          final scrollY = double.tryParse(parts[0]) ?? 0;
          final pageHeight = double.tryParse(parts[1]) ?? 1;
          widget.onScroll(scrollY, pageHeight);
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
    if (widget.initialScrollOffset > 0) {
      await _controller.runJavaScript(
        'window.scrollTo(0, ${widget.initialScrollOffset});',
      );
    }
    await _injectScrollListener();
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
  }

  Future<void> _injectScrollListener() async {
    await _controller.runJavaScript('''
      (function() {
        let timer = null;
        window.addEventListener('scroll', function() {
          if (timer) return;
          timer = setTimeout(function() {
            timer = null;
            ScrollBridge.postMessage(
              window.scrollY + ',' + document.body.scrollHeight
            );
          }, 500);
        });
      })();
    ''');
  }

  Future<void> updateStyle(ReaderSettings settings) async {
    await _injectCss(settings);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
