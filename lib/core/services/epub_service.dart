import 'dart:io';
import 'dart:convert';
import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/book.dart';

class EpubService {
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

  Future<List<String>> extractChapters(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final epub = await EpubReader.readBook(bytes);
    final chapters = <String>[];
    _collectChapterHtmls(epub.Chapters ?? [], chapters, epub);
    return chapters;
  }

  void _collectChapterHtmls(
      List<EpubChapter> src, List<String> out, EpubBook epub) {
    for (final ch in src) {
      final html = _buildChapterHtml(ch, epub);
      if (html.trim().isNotEmpty) out.add(html);
      if (ch.SubChapters != null && ch.SubChapters!.isNotEmpty) {
        _collectChapterHtmls(ch.SubChapters!, out, epub);
      }
    }
  }

  Future<List<String>> extractChapterTitles(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final epub = await EpubReader.readBook(bytes);
    final titles = <String>[];
    _collectChapterTitles(epub.Chapters ?? [], titles);
    return titles;
  }

  Future<List<int>> extractChapterLevels(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final epub = await EpubReader.readBook(bytes);
    final levels = <int>[];
    _collectChapterLevels(epub.Chapters ?? [], 0, levels);
    return levels;
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

  Future<List<String>> extractChapterTexts(String filePath) async {
    final htmlChapters = await extractChapters(filePath);
    return htmlChapters.map(_htmlToPlainText).toList();
  }

  String _buildChapterHtml(EpubChapter chapter, EpubBook epub) {
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

  String _replaceImagesWithBase64(String html, EpubBook epub) {
    final images = epub.Content?.Images;
    if (images != null) {
      for (final image in images.values) {
        if (image.FileName != null && image.Content != null) {
          final base64Str = base64Encode(image.Content!);
          html = html.replaceAll(
            RegExp(RegExp.escape(image.FileName!), caseSensitive: false),
            'data:image/${_imageExtension(image.FileName!)};base64,$base64Str',
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
    String text = html.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
