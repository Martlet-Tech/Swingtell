import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/models/news_summary_record.dart';
import '../../core/services/news_service.dart';
import '../../core/services/news_storage_service.dart';
import '../../core/services/tts/tts_pipeline.dart';
import '../../core/services/settings_service.dart';

class NewsSummaryScreen extends StatefulWidget {
  final String topicName;
  final String topicPrompt;
  final String timeRange;
  final String? globalPrompt;
  final bool webSearchEnabled;

  /// 查看已保存的历史记录时传入
  final String? savedHtml;
  final String? savedPlainText;

  /// 用于新生成时保存到历史
  final String? topicId;

  const NewsSummaryScreen({
    super.key,
    required this.topicName,
    required this.topicPrompt,
    this.timeRange = '',
    this.globalPrompt,
    this.webSearchEnabled = false,
    this.savedHtml,
    this.savedPlainText,
    this.topicId,
  });

  @override
  State<NewsSummaryScreen> createState() => _NewsSummaryScreenState();
}

class _NewsSummaryScreenState extends State<NewsSummaryScreen> {
  late final WebViewController _webController;
  bool _loading = true;
  String? _error;
  String? _plainText;
  bool _ttsPlaying = false;
  StreamSubscription<TtsState>? _ttsSub;
  final List<String> _progressLog = [];
  String? _tokenInfo;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'TapBridge',
        onMessageReceived: (msg) {
          if (msg.message == 'double_tap') _toggleTts();
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (request.url.startsWith('http')) {
            launchUrl(Uri.parse(request.url),
                mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
    _fetchSummary();
    _listenTts();
  }

  @override
  void dispose() {
    _ttsSub?.cancel();
    context.read<TtsPipeline>().stop();
    super.dispose();
  }

  void _listenTts() {
    final tts = context.read<TtsPipeline>();
    _ttsSub = tts.stateStream.listen((state) {
      if (mounted) {
        setState(() => _ttsPlaying = state.isPlaying);
      }
    });
  }

  Future<void> _fetchSummary() async {
    // 查看已保存的历史 → 直接加载
    if (widget.savedHtml != null) {
      _plainText = widget.savedPlainText;
      setState(() => _loading = false);
      await _webController.loadHtmlString(widget.savedHtml!);
      await _injectTapJs();
      return;
    }

    // 新生成
    final newsService = context.read<NewsService>();
    final rssSources = context.read<NewsStorageService>().rssSources;
    final result = await newsService.getNewsSummary(
      topicPrompt: widget.topicPrompt,
      timeRange: widget.timeRange,
      globalPrompt: widget.globalPrompt,
      webSearchEnabled: widget.webSearchEnabled,
      rssSources: rssSources,
      onProgress: (log) {
        if (!mounted) return;
        if (log.startsWith('usage:')) {
          final parts = log.substring(6).split(',');
          if (parts.length == 3) {
            _tokenInfo = 'Token 消耗  输入 ${parts[0]}  输出 ${parts[1]}  总计 ${parts[2]}';
          }
        } else {
          setState(() => _progressLog.add(log));
        }
      },
    );
    if (!mounted) return;

    final isError = result.startsWith('<p style="color:red');
    if (isError) {
      setState(() {
        _error = result;
        _loading = false;
      });
      return;
    }

    final html = _wrapHtml(result);
    _plainText = _stripHtml(result);
    setState(() => _loading = false);
    await _webController.loadHtmlString(html);
    await _injectTapJs();

    // 保存到历史
    if (widget.topicId != null && mounted) {
      final storage = context.read<NewsStorageService>();
      storage.saveSummaryRecord(
        NewsSummaryRecord(
          topicId: widget.topicId!,
          topicName: widget.topicName,
          timeRange: widget.timeRange,
          htmlContent: html,
          plainText: _plainText ?? '',
          tokenInfo: _tokenInfo,
        ),
      );
    }
  }

  Widget _tokenBar() {
    if (_tokenInfo == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Colors.grey[100],
      child: Text(
        _tokenInfo!,
        style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace'),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _injectTapJs() async {
    await _webController.runJavaScript('''
      (function() {
        if (window._newsTapInjected) return;
        window._newsTapInjected = true;
        var lastTapTime = 0;
        var tapTimer = null;
        document.addEventListener('click', function(e) {
          var now = Date.now();
          if (now - lastTapTime < 350) {
            if (tapTimer) { clearTimeout(tapTimer); tapTimer = null; }
            lastTapTime = 0;
            TapBridge.postMessage('double_tap');
          } else {
            lastTapTime = now;
            tapTimer = setTimeout(function() {
              tapTimer = null;
            }, 350);
          }
        });
      })();
    ''');
  }

  void _toggleTts() async {
    final tts = context.read<TtsPipeline>();
    if (_ttsPlaying) {
      await tts.pause();
    } else {
      await tts.stop();
      if (_plainText != null && _plainText!.isNotEmpty) {
        await tts.start(
          chapterTexts: [_plainText!],
          chapterIndex: 0,
        );
      }
    }
  }

  String _wrapHtml(String bodyContent) {
    final settings = context.read<SettingsService>().settings;
    final isDark = settings.colorThemeIndex == 1;
    final bg = isDark ? '#1a1a2e' : '#f4f4f4';
    final cardBg = isDark ? '#16213e' : '#ffffff';
    final text = isDark ? '#e0e0e0' : '#333333';
    final heading = isDark ? '#ffffff' : '#1a1a1a';
    final meta = isDark ? '#999' : '#888';
    return '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
* { box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  margin: 0;
  padding: 16px;
  background: $bg;
  color: $text;
  line-height: 1.6;
  -webkit-user-select: text;
  user-select: text;
}
.news-item {
  background: $cardBg;
  border-radius: 12px;
  padding: 16px;
  margin-bottom: 16px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.08);
}
.news-item h3 {
  margin: 0 0 8px 0;
  font-size: 17px;
  color: $heading;
  line-height: 1.4;
}
.meta {
  font-size: 13px;
  color: $meta;
  margin-bottom: 8px;
}
.news-item p {
  margin: 0 0 12px 0;
  color: $text;
}
.source-link {
  display: inline-block;
  color: #1976d2;
  text-decoration: none;
  font-size: 14px;
  font-weight: 500;
}
a { color: #1976d2; }
h2 { font-size: 20px; color: $heading; }
</style>
</head>
<body>
$bodyContent
</body>
</html>''';
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '\n')
        .replaceAll('</p>', '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? '${widget.topicName} - ${widget.timeRange}' : widget.topicName),
        actions: [
          if (_plainText != null)
            IconButton(
              icon: Icon(_ttsPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: _toggleTts,
              tooltip: _ttsPlaying ? '暂停朗读' : '朗读',
            ),
        ],
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),
                ..._progressLog.map((log) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontFamily: 'monospace',
                    ),
                  ),
                )),
              ],
            )
          : Column(
              children: [
                _tokenBar(),
                Expanded(
                  child: _error != null
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: WebViewWidget(controller: _webController),
                        )
                      : WebViewWidget(controller: _webController),
                ),
              ],
            ),
    );
  }
}
