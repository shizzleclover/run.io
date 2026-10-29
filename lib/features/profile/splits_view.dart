import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';

/// One row per km (or mile): the time, and a bar showing pace. Longer bar
/// is faster. The fastest split is highlighted.
class SplitsView extends StatelessWidget {
  const SplitsView({
    super.key,
    required this.splits,
    required this.miles,
    required this.color,
  });

  final List<int> splits;
  final bool miles;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) return const SizedBox.shrink();
    final fastest = splits.reduce(math.min);
    final slowest = splits.reduce(math.max);
    final unit = miles ? 'Mile' : 'Km';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Splits', style: AppText.section),
        const SizedBox(height: 12),
        for (var i = 0; i < splits.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              label:
                  '$unit ${i + 1}, ${Fmt.duration(Duration(seconds: splits[i]))}'
                  '${splits[i] == fastest ? ', fastest' : ''}',
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text('$unit ${i + 1}', style: AppText.small),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      Fmt.duration(Duration(seconds: splits[i])),
                      style: AppText.number(
                        15,
                        color: splits[i] == fastest
                            ? AppColors.ink(color)
                            : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // Slowest split still gets a third of the width.
                        final range = math.max(1, slowest - fastest);
                        final t = 1 - (splits[i] - fastest) / range;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 10,
                            width: box.maxWidth * (0.35 + 0.65 * t),
                            decoration: BoxDecoration(
                              color: splits[i] == fastest
                                  ? color
                                  : color.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
