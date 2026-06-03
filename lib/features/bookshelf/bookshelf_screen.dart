import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/epub_service.dart';
import '../../core/services/progress_service.dart';
import '../../shared/widgets/book_cover_card.dart';
import 'bookshelf_viewmodel.dart';

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  late BookshelfViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = BookshelfViewModel(
      storageService: context.read<StorageService>(),
      epubService: context.read<EpubService>(),
      progressService: context.read<ProgressService>(),
    );
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final books = _vm.books;
        final progressMap = _vm.progressMap;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2 / 3,
          ),
          itemCount: books.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return AddBookCard(onTap: () {
                final messenger = ScaffoldMessenger.of(context);
                _vm.importBook().catchError((e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('导入失败: $e')),
                  );
                });
              });
            }
            final book = books[index - 1];
            return BookCoverCard(
              book: book,
              progress: progressMap[book.id]?.percentage,
              onDelete: () => _vm.deleteBook(book.id),
            );
          },
        );
      },
    );
  }
}
