import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/models/book.dart';

const _kCardColors = [
  Color(0xFF5C6BC0), Color(0xFFAB47BC), Color(0xFFEC407A),
  Color(0xFFEF5350), Color(0xFFFF7043), Color(0xFFFFA726),
  Color(0xFF66BB6A), Color(0xFF26A69A), Color(0xFF42A5F5),
  Color(0xFF78909C),
];

Color _colorForBook(String title) {
  return _kCardColors[title.hashCode.abs() % _kCardColors.length];
}

class AddBookCard extends StatelessWidget {
  final VoidCallback onTap;
  const AddBookCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 2, strokeAlign: BorderSide.strokeAlignInside),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: Icon(Icons.add, size: 48, color: Colors.grey)),
      ),
    );
  }
}

class BookCoverCard extends StatelessWidget {
  final Book book;
  final double? progress;
  final VoidCallback? onDelete;

  const BookCoverCard({super.key, required this.book, this.progress, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bgColor = _colorForBook(book.title);
    final progressText = progress != null ? '${(progress! * 100).toInt()}%' : '0%';
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/reader', arguments: book),
      onLongPress: () => _showDeleteDialog(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              image: book.coverBase64 != null
                  ? DecorationImage(
                      image: MemoryImage(base64Decode(book.coverBase64!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                if (book.coverBase64 == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        book.title,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                if (progress != null)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(progressText, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定删除《${book.title}》吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
