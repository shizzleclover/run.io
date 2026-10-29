import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../state/game_controller.dart';
import '../../shared/widgets/player_chip.dart';
import '../../shared/widgets/player_sheet.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(leaderboardProvider);
    final game = ref.watch(gameProvider);
    final me = game.user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(indent: 64, endIndent: 8),
        itemBuilder: (context, i) {
          final e = entries[i];
          final isMe = e.player.id == me;
          final color = Color(e.player.color);
          final area = Fmt.area(e.areaM2);

          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => showPlayerSheet(context, e.player.id),
            // You get a quiet highlight; everyone else is a plain row.
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.surface : null,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${i + 1}',
                      style: AppText.number(
                        17,
                        color: i == 0 ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: PlayerChip(
                      name: isMe
                          ? '${e.player.name} (you)'
                          : e.player.shownName,
                      style: AppText.body.copyWith(
                        fontWeight: isMe ? FontWeight.w600 : FontWeight.w500,
                      ),
                      color: color,
                      avatar: isMe ? e.player.avatar : e.player.shownAvatar,
                      seed: e.player.id,
                      avatarSize: 36,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: area.value, style: AppText.number(16)),
                        TextSpan(
                          text: ' ${area.unit}',
                          style: AppText.unit(12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
