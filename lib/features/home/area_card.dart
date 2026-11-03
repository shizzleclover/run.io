import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/invite.dart';
import '../../shared/motion/motion.dart';
import '../../state/area.dart';
import '../../state/game_controller.dart';

/// Where you play, who holds it, and the two ways to fill it with real
/// people: invite runners, run with a crew.
class AreaCard extends ConsumerWidget {
  const AreaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ref.watch(areaProvider);
    final share = ref.watch(ghostShareProvider);
    final crew = ref.watch(gameProvider.select((g) => g.myCrew));
    final pct = (share.fraction * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(area?.name ?? 'Your area', style: AppText.section),
        const SizedBox(height: AppSpace.xs),
        Text(
          share.ghosts == 0
              ? 'All the land here is held by real runners.'
              : '$pct% of the claimed land here is held by '
                    '${share.ghosts} ghost runner${share.ghosts == 1 ? '' : 's'}. '
                    'They\'re simulated, and retreat as real runners join.',
          style: AppText.small,
        ),
        if (share.ghosts > 0) ...[
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Icon(AppIcons.ghost, size: 16, color: AppColors.textMuted),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: AnimatedBar(progress: share.fraction)),
              const SizedBox(width: AppSpace.sm),
              Text('$pct%', style: AppText.number(13)),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => shareText(appInvite(area: area?.name)),
                icon: const Icon(AppIcons.invite, size: AppSize.iconSm),
                label: const Text('Invite', maxLines: 1),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/crew'),
                icon: const Icon(AppIcons.crew, size: AppSize.iconSm),
                label: Text(
                  crew?.name ?? 'Crew',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
