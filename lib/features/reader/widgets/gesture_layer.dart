import 'package:flutter/material.dart';

class GestureLayer extends StatelessWidget {
  final VoidCallback onTapCenter;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  const GestureLayer({
    super.key,
    required this.onTapCenter,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapCenter,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.translucent,
      child: const SizedBox.expand(),
    );
  }
}
