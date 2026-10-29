import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';

/// "run.io" with the dot in the player's colour.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = AppText.title(size);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'run', style: style),
          TextSpan(
            text: '.',
            style: style.copyWith(color: AppColors.ink(color)),
          ),
          TextSpan(text: 'io', style: style),
        ],
      ),
    );
  }
}
