import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/storage_service.dart';
import 'core/services/progress_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/epub_service.dart';
import 'core/services/tts/tts_pipeline_impl.dart';
import 'core/services/tts/tts_pipeline.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final progressService = ProgressService();
  await progressService.init();

  final settingsService = SettingsService();
  await settingsService.init();

  final epubService = EpubService();

  final ttsPipeline = TtsPipelineImpl();
  await ttsPipeline.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<EpubService>.value(value: epubService),
        Provider<ProgressService>.value(value: progressService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        Provider<TtsPipeline>.value(value: ttsPipeline),
      ],
      child: const App(),
    ),
  );
}
