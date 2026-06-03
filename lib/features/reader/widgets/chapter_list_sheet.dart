import 'package:flutter/material.dart';

class ChapterListSheet extends StatelessWidget {
  final List<String> titles;
  final int currentIndex;
  final void Function(int index) onTap;

  const ChapterListSheet({
    super.key,
    required this.titles,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: const Text('章节目录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: titles.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == currentIndex;
                  return ListTile(
                    selected: isCurrent,
                    selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                    title: Text(
                      titles.isNotEmpty && index < titles.length
                          ? titles[index]
                          : '第 ${index + 1} 章',
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      onTap(index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
