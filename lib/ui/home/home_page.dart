import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/book.dart';
import '../../models/chapter.dart';
import '../../services/file_parser/epub_parser.dart';
import '../../services/storage/database.dart';
import '../../utils/constants.dart';
import '../reader/reader_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _recentBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentBooks();
  }

  Future<void> _loadRecentBooks() async {
    setState(() => _isLoading = true);
    try {
      final books = await DatabaseService.getRecentBooks();
      if (mounted) setState(() => _recentBooks = books);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEpub() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = result.files.single;
    final originalPath = file.path!;

    // Check if already imported (by original path; for SAF URIs we skip dup check)
    final existing = await DatabaseService.getBookByPath(originalPath);
    if (existing != null) {
      _openReader(existing['id'] as String);
      return;
    }

    _showImporting();
    try {
      // Read bytes (handles content:// URIs on Android)
      final bytes = file.bytes ?? await File(originalPath).readAsBytes();

      // Save to app local storage
      final appDir = await getApplicationDocumentsDirectory();
      final bookDir = Directory(p.join(appDir.path, 'books'));
      if (!await bookDir.exists()) await bookDir.create(recursive: true);

      final localPath = p.join(bookDir.path, file.name);
      await File(localPath).writeAsBytes(bytes);

      // Parse from local copy
      final parser = EpubParser();
      final meta = await parser.parseMeta(localPath);
      final chapterItems = await parser.parseChapters(localPath);

      // Count characters per chapter
      final chapters = <Chapter>[];
      for (int i = 0; i < chapterItems.length; i++) {
        final content = await parser.getChapterContent(localPath, i);
        chapters.add(Chapter(
          id: const Uuid().v4(),
          bookId: '', // will be set after book creation
          index: chapterItems[i].index,
          title: chapterItems[i].title,
          startPos: 0,
          endPos: content.length,
          charCount: content.length,
        ));
      }

      final bookId = const Uuid().v4();
      final now = DateTime.now();
      final book = Book(
        id: bookId,
        title: meta.title,
        author: meta.author,
        filePath: localPath,
        format: BookFormat.epub,
        fileSize: bytes.length,
        totalChapters: chapters.length,
        createdAt: now,
        updatedAt: now,
      );

      await DatabaseService.insertBook(book.toMap());

      // Insert chapters with bookId
      final chapterMaps = chapters
          .map((ch) => Chapter(
                id: const Uuid().v4(),
                bookId: bookId,
                index: ch.index,
                title: ch.title,
                startPos: ch.startPos,
                endPos: ch.endPos,
                charCount: ch.charCount,
              ).toMap())
          .toList();
      await DatabaseService.insertChapters(chapterMaps);

      await _loadRecentBooks();
      // Dismiss import snackbar
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) _openReader(bookId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  void _showImporting() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('正在导入 EPUB...'),
        ]),
        duration: Duration(seconds: 30),
      ),
    );
  }

  void _openReader(String bookId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(bookId: bookId),
      ),
    );
  }

  Future<void> _deleteBook(String id) async {
    await DatabaseService.deleteBook(id);
    await _loadRecentBooks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SwingTell')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEpub,
        icon: const Icon(Icons.add),
        label: const Text('打开 EPUB'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentBooks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded, size: 72, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              Text('还没有读过书', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              Text('点击下方按钮打开 EPUB 文件', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecentBooks,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _recentBooks.length,
        itemBuilder: (context, index) => _buildBookCard(_recentBooks[index]),
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final title = book['title'] as String? ?? '未知标题';
    final author = book['author'] as String? ?? '';
    final progress = (book['total_progress'] as num?)?.toDouble() ?? 0.0;
    final progressTime = book['progress_time'] as int?;
    final id = book['id'] as String;

    final timeStr = progressTime != null
        ? _formatTime(DateTime.fromMillisecondsSinceEpoch(progressTime))
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 64,
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.book, color: AppConstants.accentColor),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (author.isNotEmpty) Text(author, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade800,
                valueColor: AlwaysStoppedAnimation(AppConstants.primaryColor),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text('${(progress * 100).toInt()}%',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                const Spacer(),
                if (timeStr.isNotEmpty)
                  Text(timeStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'delete') _deleteBook(id);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'delete', child: Text('删除记录')),
          ],
        ),
        onTap: () => _openReader(id),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}
