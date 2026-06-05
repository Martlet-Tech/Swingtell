import 'package:flutter/material.dart';

class GestureLayer extends StatelessWidget {
  final VoidCallback onTapCenter;

  const GestureLayer({
    super.key,
    required this.onTapCenter,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapCenter,
      behavior: HitTestBehavior.translucent,
      child: const SizedBox.expand(),
    );
  }
}
