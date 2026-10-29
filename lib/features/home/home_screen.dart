import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../core/live/presence.dart';
import '../../core/models.dart';
import '../../engine/geo.dart';
import '../../shared/widgets/player_avatar.dart';
import '../../shared/widgets/player_sheet.dart';
import '../../state/game_controller.dart';
import '../../state/live_providers.dart';
import '../../state/navigation.dart';
import '../../shared/motion/motion.dart';
import 'heatmaps.dart';
import 'week_card.dart';
import '../../app/theme/app_icons.dart';

/// Your week at a glance, what needs defending, and the people you follow.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Switch to the map tab, looking at [p].
  static void showOnMap(BuildContext context, WidgetRef ref, LatLng p) {
    ref.read(mapFocusProvider.notifier).focus(p);
    context.go('/map');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final user = game.user;
    if (user == null) return const Scaffold();
    final color = Color(user.color);
    final cellArea = ref.watch(cellAreaProvider);
    final board = ref.watch(leaderboardProvider);
    final stale = ref.watch(staleCellsProvider);
    final live = ref.watch(liveRunnersProvider).value ?? const <LiveRunner>[];
    final place = ref.watch(homeStateProvider)?.name;

    final myCells = game.owners.values.where((o) => o == user.id).length;
    final rank = board.indexWhere((e) => e.player.id == user.id) + 1;
    final total = Fmt.distance(
      game.runs.fold(0.0, (a, r) => a + r.distanceM),
      miles: game.settings.useMiles,
    );

    final following = [
      for (final r in game.rivals)
        if (game.following.contains(r.id)) r,
    ];
    // Anonymous runners can't be followed or suggested.
    final others = [
      for (final r in game.rivals)
        if (!game.following.contains(r.id) && r.discoverable) r,
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.sm,
            AppSpace.screen,
            AppSpace.xxl,
          ),
          children: [
            // Greeting
            Row(
              children: [
                GestureDetector(
                  onTap: () => showPlayerSheet(context, user.id),
                  child: PlayerAvatar(
                    avatar: user.avatar,
                    seed: user.id,
                    color: color,
                    size: AppSize.avatar,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(), style: AppText.small),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title(18),
                            ),
                          ),
                          if (!user.discoverable) ...[
                            const SizedBox(width: AppSpace.sm),
                            const _AnonymousBadge(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(AppIcons.settings),
                  color: AppColors.textSecondary,
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xxl),

            // The one number that matters. It counts up to its new value.
            FadeSlideIn(
              child: AnimatedValue(
                value: myCells * cellArea,
                builder: (context, m2) {
                  final a = Fmt.area(m2);
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: a.value, style: AppText.number(56)),
                          TextSpan(text: ' ${a.unit}', style: AppText.unit(22)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              [
                'owned',
                if (rank > 0) '#$rank${place == null ? '' : ' in $place'}',
                '${total.value} ${total.unit} run',
              ].join('  ·  '),
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: 24),

            const _StartButton(),

            if (stale.isNotEmpty) ...[
              const SizedBox(height: 12),
              _FadingRow(
                count: stale.length,
                onTap: () => showOnMap(
                  context,
                  ref,
                  ref.read(gridProvider).center(stale.first),
                ),
              ),
            ],

            const SizedBox(height: AppSpace.section),
            const FadeSlideIn(index: 1, child: WeekCard()),
            const SizedBox(height: AppSpace.section),
            const FadeSlideIn(index: 2, child: ActivityCalendar()),
            const SizedBox(height: AppSpace.section),
            const FadeSlideIn(index: 3, child: RouteHeatmap()),

            if (live.isNotEmpty) ...[
              const SizedBox(height: AppSpace.section),
              const _SectionTitle('Out running now'),
              for (final r in live)
                if (game.playerById(r.playerId) case final p?)
                  _PlayerRow(
                    player: p,
                    subtitle: game.following.contains(p.id)
                        ? 'Following · live'
                        : 'Live near you',
                    live: true,
                    onTap: () => showPlayerSheet(context, p.id),
                  ),
            ],

            const SizedBox(height: AppSpace.section),
            const _SectionTitle('Following'),
            if (following.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Follow runners below to keep an eye on them here.',
                  style: AppText.bodyMuted,
                ),
              ),
            for (final p in following)
              _PlayerRow(
                player: p,
                subtitle: _standing(board, p.id),
                live: live.any((r) => r.playerId == p.id),
                trailing: _FollowButton(playerId: p.id, following: true),
                onTap: () => showPlayerSheet(context, p.id),
              ),

            if (others.isNotEmpty) ...[
              const SizedBox(height: AppSpace.section),
              _SectionTitle(
                place == null ? 'Runners near you' : 'Runners in $place',
              ),
              for (final p in others)
                _PlayerRow(
                  player: p,
                  subtitle: _standing(board, p.id),
                  live: live.any((r) => r.playerId == p.id),
                  trailing: _FollowButton(playerId: p.id, following: false),
                  onTap: () => showPlayerSheet(context, p.id),
                ),
            ],

            const SizedBox(height: 28),
            Row(
              children: [
                Icon(AppIcons.invite, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Invite friends and your running club. Coming with '
                    'accounts.',
                    style: AppText.small.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _standing(List<LeaderEntry> board, String id) {
    final i = board.indexWhere((e) => e.player.id == id);
    if (i < 0) return '';
    final area = Fmt.area(board[i].areaM2);
    return '#${i + 1} · ${area.value} ${area.unit}';
  }
}

/// Full-width solid accent. During the cooldown after being cut it turns
/// into a quiet countdown.
class _StartButton extends ConsumerWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cooldown = ref.watch(cooldownProvider).value;
    final out = cooldown != null;
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: out
            ? null
            : () {
                if (ref.read(gameProvider).settings.haptics) {
                  HapticFeedback.mediumImpact();
                }
                // The map runs the 3-2-1 countdown, then starts.
                ref.read(startRequestProvider.notifier).request();
                context.go('/map');
              },
        style: FilledButton.styleFrom(
          disabledBackgroundColor: AppColors.elevated,
          disabledForegroundColor: AppColors.textSecondary,
          textStyle: AppText.title(17),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                out
                    ? 'You got cut · back in ${Fmt.duration(cooldown)}'
                    : 'Start run',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(out ? AppIcons.cooldown : AppIcons.play, size: 26),
          ],
        ),
      ),
    );
  }
}

class _FadingRow extends StatelessWidget {
  const _FadingRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.cooldown,
              size: 18,
              color: AppColors.ink(AppColors.warning),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count hexes fading. Run through them to keep them.',
                style: AppText.small.copyWith(color: AppColors.text),
              ),
            ),
            Icon(AppIcons.chevron, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: AppText.section),
  );
}

/// A plain list row: no box, just avatar, text and an action.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.subtitle,
    required this.onTap,
    this.live = false,
    this.trailing,
  });

  final Player player;
  final String subtitle;
  final VoidCallback onTap;
  final bool live;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PlayerAvatar(
                  avatar: player.shownAvatar,
                  seed: player.id,
                  color: Color(player.color),
                  size: 40,
                ),
                if (live)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.ok,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.shownName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w500),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  const _FollowButton({required this.playerId, required this.following});

  final String playerId;
  final bool following;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void toggle() => ref.read(gameProvider.notifier).toggleFollow(playerId);
    final style = TextButton.styleFrom(
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      visualDensity: VisualDensity.compact,
      textStyle: AppText.small.copyWith(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
    return following
        ? TextButton(
            onPressed: toggle,
            style: style.copyWith(
              foregroundColor: WidgetStatePropertyAll(AppColors.textSecondary),
            ),
            child: const Text('Following'),
          )
        : TextButton(
            onPressed: toggle,
            style: style.copyWith(
              backgroundColor: WidgetStatePropertyAll(
                AppColors.accent.withValues(alpha: 0.12),
              ),
            ),
            child: const Text('Follow'),
          );
  }
}

class _AnonymousBadge extends StatelessWidget {
  const _AnonymousBadge();

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Others see you as an anonymous runner',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.hidden, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text('Anonymous', style: AppText.small.copyWith(fontSize: 11)),
        ],
      ),
    ),
  );
}
