import 'package:flutter/material.dart';

class GestureLayer extends StatelessWidget {
  final String readingMode;
  final VoidCallback onTapCenter;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;

  const GestureLayer({
    super.key,
    required this.readingMode,
    required this.onTapCenter,
    this.onPrevPage,
    this.onNextPage,
  });

  @override
  Widget build(BuildContext context) {
    if (readingMode == 'page') {
      return _buildPageMode();
    }
    return _buildScrollMode();
  }

  Widget _buildPageMode() {
    return Row(
      children: [
        Expanded(child: GestureDetector(onTap: onPrevPage ?? onTapCenter)),
        Expanded(child: GestureDetector(onTap: onTapCenter)),
        Expanded(child: GestureDetector(onTap: onNextPage ?? onTapCenter)),
      ],
    );
  }

  Widget _buildScrollMode() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: GestureDetector(onTap: onTapCenter),
        ),
        Expanded(
          flex: 2,
          child: IgnorePointer(
            ignoring: false,
            child: Container(),
          ),
        ),
      ],
    );
  }
}
