import 'package:flutter/material.dart';
import '../../../core/models/reader_settings.dart';
import '../../../core/constants/app_constants.dart';

class ReaderTopBar extends StatelessWidget {
  final String title;
  final ReaderSettings settings;
  final VoidCallback onBack;
  final VoidCallback onTtsPlay;
  final VoidCallback onTtsSettings;
  final bool isTtsPlaying;

  const ReaderTopBar({
    super.key,
    required this.title,
    required this.settings,
    required this.onBack,
    required this.onTtsPlay,
    required this.onTtsSettings,
    this.isTtsPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = kColorThemes[settings.colorThemeIndex];
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: theme.barBg.withValues(alpha: 0.95),
        boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.1))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: Icon(isTtsPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: onTtsPlay,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: onTtsSettings,
          ),
        ],
      ),
    );
  }
}
