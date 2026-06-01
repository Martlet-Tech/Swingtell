import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/chapter_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/settings_repository.dart';
import 'database_provider.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(db: ref.read(databaseServiceProvider));
});

final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  return ChapterRepository(db: ref.read(databaseServiceProvider));
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(db: ref.read(databaseServiceProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});
