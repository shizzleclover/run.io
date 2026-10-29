import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';

/// Big number, small muted unit, tiny uppercase label.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.size = 28,
    this.color,
    this.align = CrossAxisAlignment.start,
  });

  final String value;
  final String? unit;
  final String label;
  final double size;
  final Color? color;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final c = color;
    final alignment = align == CrossAxisAlignment.end
        ? Alignment.centerRight
        : Alignment.centerLeft;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shrink long values (an hour-long run, a big pace) instead of
        // overflowing narrow columns.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AppText.number(
                    size,
                    color: c == null ? null : AppColors.ink(c),
                  ),
                ),
                if (unit != null)
                  TextSpan(text: ' $unit', style: AppText.unit(size * 0.45)),
              ],
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppText.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
