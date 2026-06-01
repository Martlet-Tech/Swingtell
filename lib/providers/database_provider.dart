import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/database_service.dart';

/// DatabaseService 单例，ref.onDispose 自动关闭数据库连接
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final db = DatabaseService();
  ref.onDispose(() => db.close());
  return db;
});
