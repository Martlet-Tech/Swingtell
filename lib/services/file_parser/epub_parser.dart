import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'parser_base.dart';

class EpubParser implements BookParser {
  @override
  Future<BookMeta> parseMeta(String filePath) async {
    final archive = await _openArchive(filePath);
    final opfFile = _findOpfFile(archive);
    final opfXml = XmlDocument.parse(utf8.decode(_readFile(archive, opfFile)!));

    String title = '';
    String author = '';

    final meta = opfXml.findAllElements('metadata').firstOrNull;
    if (meta != null) {
      title = meta.findElements('title').firstOrNull?.innerText.trim() ?? '';
      author = meta.findElements('creator').firstOrNull?.innerText.trim() ?? '';
    }

    return BookMeta(
      title: title.isNotEmpty ? title : _guessTitle(filePath),
      author: author,
    );
  }

  @override
  Future<List<ChapterItem>> parseChapters(String filePath) async {
    final archive = await _openArchive(filePath);
    final opfFile = _findOpfFile(archive);
    final opfXml = XmlDocument.parse(utf8.decode(_readFile(archive, opfFile)!));

    final opfDir = _parentDir(opfFile);
    final spine = opfXml.findAllElements('spine').firstOrNull;
    if (spine == null) return [];

    final manifest = <String, String>{};
    for (final item in opfXml.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) manifest[id] = href;
    }

    // NCX titles (EPUB 2)
    final ncxTitles = <String>[];
    for (final ncxRef in opfXml.findAllElements('item')) {
      final mediaType = ncxRef.getAttribute('media-type');
      final href = ncxRef.getAttribute('href');
      if (mediaType == 'application/x-dtbncx+xml' && href != null) {
        final ncxPath = _resolvePath(opfDir, href);
        final ncxData = _readFile(archive, ncxPath);
        if (ncxData != null) {
          try {
            final ncxXml = XmlDocument.parse(utf8.decode(ncxData));
            for (final navPoint in ncxXml.findAllElements('navPoint')) {
              final text = navPoint.findAllElements('text').firstOrNull;
              if (text != null) ncxTitles.add(text.innerText.trim());
            }
          } catch (_) {}
        }
      }
    }

    // Try nav.xhtml for EPUB 3
    if (ncxTitles.isEmpty) {
      for (final item in opfXml.findAllElements('item')) {
        final properties = item.getAttribute('properties') ?? '';
        final href = item.getAttribute('href');
        if (properties.contains('nav') && href != null) {
          final navPath = _resolvePath(opfDir, href);
          final navData = _readFile(archive, navPath);
          if (navData != null) {
            try {
              final navXml = XmlDocument.parse(utf8.decode(navData));
              for (final a in navXml.findAllElements('a')) {
                final text = a.innerText.trim();
                if (text.isNotEmpty) ncxTitles.add(text);
              }
            } catch (_) {}
          }
        }
      }
    }

    final items = spine.findElements('itemref');
    final chapters = <ChapterItem>[];
    int index = 0;
    for (final itemref in items) {
      final idref = itemref.getAttribute('idref');
      if (idref == null) continue;
      final href = manifest[idref];
      if (href == null) continue;

      final title = index < ncxTitles.length ? ncxTitles[index] : '第${index + 1}章';
      chapters.add(ChapterItem(
        index: index,
        title: title,
        href: _resolvePath(opfDir, href),
      ));
      index++;
    }

    return chapters;
  }

  @override
  Future<String> getChapterContent(String filePath, int chapterIndex) async {
    final blocks = await getChapterBlocks(filePath, chapterIndex);
    return blocks.map((b) => b.text).join('\n');
  }

  @override
  Future<List<TextBlock>> getChapterBlocks(String filePath, int chapterIndex) async {
    final chapters = await parseChapters(filePath);
    if (chapterIndex >= chapters.length) return [];
    final archive = await _openArchive(filePath);
    final html = _readChapterRaw(archive, chapters[chapterIndex].href!);
    if (html == null) return [];
    return _parseBlocks(html);
  }

  Future<List<ChapterContent>> getAllChapters(String filePath) async {
    final chapters = await parseChapters(filePath);
    final archive = await _openArchive(filePath);

    final results = <ChapterContent>[];
    for (final ch in chapters) {
      if (ch.href == null) continue;
      results.add(ChapterContent(
        index: ch.index,
        title: ch.title,
        content: await _readChapterText(archive, ch.href!),
      ));
    }
    return results;
  }

  Future<String> getFullText(String filePath) async {
    final chapters = await getAllChapters(filePath);
    return chapters.map((c) => c.content).join('\n\n');
  }

  // --- Private helpers ---

  Future<Archive> _openArchive(String filePath) async {
    final data = await File(filePath).readAsBytes();
    return ZipDecoder().decodeBytes(data);
  }

  Future<String> _readChapterText(Archive archive, String href) async {
    final chapterData = _readFile(archive, href);
    if (chapterData == null) {
      // Fallback: try matching by filename only
      final fileName = href.split('/').last;
      for (final file in archive.files) {
        if (file.name.endsWith('/$fileName') || file.name == fileName) {
          final content = file.content;
          if (content != null) return _stripHtmlSimple(utf8.decode(content));
        }
      }
      // Fallback: file not found by any path, return empty
      return '';
    }
    // HTML files often aren't well-formed XML, use regex stripping directly
    return _stripHtmlSimple(utf8.decode(chapterData));
  }

  /// Resolve a relative href against the OPF directory.
  String _resolvePath(String opfDir, String href) {
    if (opfDir == '.') return href;
    // Handle relative paths like "../Text/chapter1.xhtml"
    final resolved = href.startsWith('../')
        ? '$opfDir/$href'
        : '$opfDir/$href';
    // Normalize ".." components
    final parts = resolved.split('/');
    final result = <String>[];
    for (final p in parts) {
      if (p == '..') {
        if (result.isNotEmpty) result.removeLast();
      } else if (p != '.') {
        result.add(p);
      }
    }
    return result.join('/');
  }

  List<int>? _readFile(Archive archive, String path) {
    final normalized = path.replaceAll('\\', '/');
    // Try exact match first
    for (final file in archive.files) {
      if (file.name == normalized) return file.content;
    }
    // Try with './' prefix removed
    if (normalized.startsWith('./')) {
      final withoutDot = normalized.substring(2);
      for (final file in archive.files) {
        if (file.name == withoutDot) return file.content;
      }
    }
    // Try without leading '/'
    if (normalized.startsWith('/')) {
      final withoutLeading = normalized.substring(1);
      for (final file in archive.files) {
        if (file.name == withoutLeading) return file.content;
      }
    }
    return null;
  }

  String _findOpfFile(Archive archive) {
    final containerData = _readFile(archive, 'META-INF/container.xml');
    if (containerData != null) {
      try {
        final xml = XmlDocument.parse(utf8.decode(containerData));
        for (final rootfile in xml.findAllElements('rootfile')) {
          final path = rootfile.getAttribute('full-path');
          if (path != null) return path;
        }
      } catch (_) {}
    }
    for (final file in archive.files) {
      if (file.name.endsWith('.opf')) return file.name;
    }
    throw FormatException('Cannot find OPF file in EPUB');
  }

  String _parentDir(String path) {
    final idx = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(0, idx) : '.';
  }

  /// Read raw HTML from archive for a chapter href.
  String? _readChapterRaw(Archive archive, String href) {
    final data = _readFile(archive, href);
    if (data != null) return utf8.decode(data);
    final fileName = href.split('/').last;
    for (final file in archive.files) {
      if (file.name.endsWith('/$fileName') || file.name == fileName) {
        final content = file.content;
        if (content != null) return utf8.decode(content);
      }
    }
    return null;
  }

  /// Parse HTML into blocks with heuristic heading detection.
  List<TextBlock> _parseBlocks(String html) {
    final text = _stripHtmlSimple(html);
    if (text.isEmpty) return [];

    final blocks = <TextBlock>[];
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      blocks.add(TextBlock(
        text: trimmed,
        scale: _isLikelyHeading(trimmed) ? 1.4 : 1.0,
      ));
    }
    return blocks;
  }

  /// Heuristic: short line without sentence-ending punctuation → likely a heading.
  bool _isLikelyHeading(String text) {
    if (text.length > 25) return false;
    return !RegExp(r'[。！？）\)]$').hasMatch(text);
  }

  /// Strip HTML tags, keeping paragraph structure and decoding entities.
  String _stripHtmlSimple(String html) {
    // Remove scripts and styles
    var text = html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');
    text = text.replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '');
    // Replace block-level tags with double newline to preserve paragraph breaks
    text = text.replaceAll(RegExp(r'</?(?:p|div|h[1-6]|blockquote|li|section|article|header|footer)[^>]*>', caseSensitive: false), '\n\n');
    // Replace <br> with single newline
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    // Remove remaining tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode HTML entities
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&apos;', "'");
    text = text.replaceAll('&mdash;', '—');
    text = text.replaceAll('&hellip;', '…');
    text = text.replaceAll('&ldquo;', '"');
    text = text.replaceAll('&rdquo;', '"');
    // Decode numeric entities (decimal and hex)
    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)));
    text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
    // Collapse multiple newlines to at most 2
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    // Within each line, collapse whitespace to single space
    final lines = text.split('\n').map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim()).toList();
    // Remove empty lines at start and end
    while (lines.isNotEmpty && lines.first.isEmpty) lines.removeAt(0);
    while (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return lines.join('\n');
  }

  String _guessTitle(String filePath) {
    return File(filePath).uri.pathSegments.last
        .replaceAll(RegExp(r'\.epub$', caseSensitive: false), '');
  }
}
