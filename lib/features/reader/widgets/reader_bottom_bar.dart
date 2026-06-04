import 'package:flutter/material.dart';

class ReaderBottomBar extends StatelessWidget {
  final VoidCallback onChapterList;
  final VoidCallback onColorTheme;
  final VoidCallback onFontSettings;
  final VoidCallback onTtsPlay;
  final VoidCallback onTtsSettings;
  final bool isTtsPlaying;

  const ReaderBottomBar({
    super.key,
    required this.onChapterList,
    required this.onColorTheme,
    required this.onFontSettings,
    required this.onTtsPlay,
    required this.onTtsSettings,
    this.isTtsPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: onChapterList,
            icon: const Icon(Icons.list),
          ),
          IconButton(
            onPressed: onColorTheme,
            icon: const Icon(Icons.palette),
          ),
          IconButton(
            onPressed: onFontSettings,
            icon: const Icon(Icons.text_fields),
          ),
          IconButton(
            onPressed: onTtsPlay,
            icon: Icon(isTtsPlaying ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            onPressed: onTtsSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}
