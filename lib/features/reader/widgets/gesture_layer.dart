import 'package:flutter/material.dart';

class GestureLayer extends StatelessWidget {
  final VoidCallback onTapCenter;

  const GestureLayer({
    super.key,
    required this.onTapCenter,
  });

  @override
  Widget build(BuildContext context) {
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
