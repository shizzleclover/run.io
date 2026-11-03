import 'package:flutter/material.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';

/// Marks a ghost runner everywhere one is named, so nobody mistakes the
/// simulated players for real people.
class GhostBadge extends StatelessWidget {
  const GhostBadge({super.key, this.compact = false});

  /// Icon only, for tight rows.
  final bool compact;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Ghost runner: holds land until real runners arrive',
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.ghost, size: 12, color: AppColors.textSecondary),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text('Ghost', style: AppText.small.copyWith(fontSize: 11)),
          ],
        ],
      ),
    ),
  );
}
