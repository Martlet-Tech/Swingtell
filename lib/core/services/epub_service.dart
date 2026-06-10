import 'dart:io';
import 'dart:convert';
import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/book.dart';

class EpubService {
  final Map<String, String> _imgCache = {};

  /// 解析 EPUB，返回 EpubBook 常驻内存
  Future<EpubBook> parseBook(String filePath) async {
    _imgCache.clear();
    final bytes = await File(filePath).readAsBytes();
    return await EpubReader.readBook(bytes);
  }

  /// 提取元数据（图书导入用）
  Future<Book> parseMetadata(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final epub = await EpubReader.readBook(bytes);
    String? coverBase64;
    if (epub.CoverImage != null) {
      final jpgBytes = img.encodeJpg(epub.CoverImage!);
      coverBase64 = base64Encode(jpgBytes);
    }
    return Book()
      ..id = const Uuid().v4()
      ..title = epub.Title ?? '未知书名'
      ..author = epub.Author ?? '未知作者'
      ..filePath = filePath
      ..coverBase64 = coverBase64
      ..addedAt = DateTime.now();
  }

  /// 展平嵌套章节（depth-first，跳过空内容章节）
  List<EpubChapter> flattenChapters(EpubBook epub) {
    final result = <EpubChapter>[];
    void walk(List<EpubChapter> src) {
      for (final ch in src) {
        final content = ch.HtmlContent ?? '';
        if (content.trim().isNotEmpty) result.add(ch);
        if (ch.SubChapters != null && ch.SubChapters!.isNotEmpty) {
          walk(ch.SubChapters!);
        }
      }
    }
    walk(epub.Chapters ?? []);
    return result;
  }

  /// 章节总数
  int chapterCount(EpubBook epub) {
    return flattenChapters(epub).length;
  }

  /// 提取所有章节纯文本（无图，极快）
  List<String> extractTextsFrom(EpubBook epub) {
    return flattenChapters(epub)
        .map((ch) => _htmlToPlainText(ch.HtmlContent ?? ''))
        .toList();
  }

  /// 提取所有章节标题
  List<String> extractTitlesFrom(EpubBook epub) {
    final titles = <String>[];
    _collectChapterTitles(epub.Chapters ?? [], titles);
    return titles;
  }

  /// 提取所有章节层级
  List<int> extractLevelsFrom(EpubBook epub) {
    final levels = <int>[];
    _collectChapterLevels(epub.Chapters ?? [], 0, levels);
    return levels;
  }

  /// 构建指定章节的 HTML（按需编码图片）
  String buildChapterHtml(EpubBook epub, int index) {
    final chapters = flattenChapters(epub);
    if (index < 0 || index >= chapters.length) return '';
    final chapter = chapters[index];
    String content = chapter.HtmlContent ?? '';
    content = _replaceImagesWithBase64(content, epub);
    return '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<style id="reader-style"></style>
</head>
<body>
$content
</body>
</html>''';
  }

  // ── 私有方法 ──

  String _replaceImagesWithBase64(String html, EpubBook epub) {
    final images = epub.Content?.Images;
    if (images != null) {
      for (final image in images.values) {
        if (image.FileName != null && image.Content != null) {
          final name = image.FileName!;
          final base64Str = _imgCache.putIfAbsent(
              name, () => base64Encode(image.Content!));
          html = html.replaceAll(
            RegExp(RegExp.escape(name), caseSensitive: false),
            'data:image/${_imageExtension(name)};base64,$base64Str',
          );
        }
      }
    }
    return html;
  }

  String _imageExtension(String href) {
    final ext = href.split('.').last.toLowerCase();
    if (ext == 'jpg') return 'jpeg';
    return ext;
  }

  String _htmlToPlainText(String html) {
    String text = html
        .replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    // 模拟浏览器 white-space:normal 的空白折叠行为
    text = text.replaceAll(RegExp(r'[ \t\r\f]+'), ' ');
    text = text.replaceAll(RegExp(r' *\n *'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  void _collectChapterLevels(
      List<EpubChapter> src, int depth, List<int> out) {
    for (final ch in src) {
      if ((ch.Title ?? '').trim().isNotEmpty) out.add(depth);
      if (ch.SubChapters != null && ch.SubChapters!.isNotEmpty) {
        _collectChapterLevels(ch.SubChapters!, depth + 1, out);
      }
    }
  }

  void _collectChapterTitles(List<EpubChapter> src, List<String> out) {
    for (final ch in src) {
      if ((ch.Title ?? '').trim().isNotEmpty) out.add(ch.Title!);
      if (ch.SubChapters != null && ch.SubChapters!.isNotEmpty) {
        _collectChapterTitles(ch.SubChapters!, out);
      }
    }
  }
}
