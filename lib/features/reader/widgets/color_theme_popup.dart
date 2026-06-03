import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class ColorThemePopup extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const ColorThemePopup({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = kColorThemes[currentIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.barBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withValues(alpha: 0.26))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('配色主题', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(kColorThemes.length, (i) {
              final t = kColorThemes[i];
              final isSelected = i == currentIndex;
              return GestureDetector(
                onTap: () => onSelected(i),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: t.bg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(blurRadius: 8, color: Colors.blue.withValues(alpha: 0.3))]
                        : null,
                  ),
                  child: Center(
                    child: Icon(Icons.text_fields, color: t.text, size: 20),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
