import 'package:flutter/material.dart';
import '../../../core/models/reader_settings.dart';
import '../../../core/constants/app_constants.dart';

class ReaderBottomBar extends StatelessWidget {
  final ReaderSettings settings;
  final VoidCallback onChapterList;
  final VoidCallback onColorTheme;
  final VoidCallback onFontSettings;

  const ReaderBottomBar({
    super.key,
    required this.settings,
    required this.onChapterList,
    required this.onColorTheme,
    required this.onFontSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = kColorThemes[settings.colorThemeIndex];
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: theme.barBg.withValues(alpha: 0.95),
        boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.1))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: onChapterList,
            icon: const Icon(Icons.list),
            label: const Text('目录'),
          ),
          TextButton.icon(
            onPressed: onColorTheme,
            icon: const Icon(Icons.palette),
            label: const Text('配色'),
          ),
          TextButton.icon(
            onPressed: onFontSettings,
            icon: const Icon(Icons.text_fields),
            label: const Text('文字'),
          ),
        ],
      ),
    );
  }
}
