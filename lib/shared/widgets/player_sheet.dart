import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../core/live/presence.dart';
import '../../engine/geo.dart';
import '../../core/api/api_client.dart';
import '../../state/account.dart';
import '../../state/cloud_sync.dart';
import '../../state/game_controller.dart';
import '../../state/live_providers.dart';
import '../../state/navigation.dart';
import '../motion/motion.dart';
import 'ghost_badge.dart';
import 'player_avatar.dart';
import 'stat_block.dart';

/// A runner's card: who they are, how they're doing, follow, and where
/// they are. Opened by tapping a marker on the map or a runner in a list.
/// Anonymous runners show only what the game itself needs: rank and land.
Future<void> showPlayerSheet(BuildContext context, String playerId) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _PlayerSheet(playerId: playerId),
  );
}

/// The server's view of a player: land everywhere (not just what's loaded
/// here) and whether they follow you. Null offline or for yourself.
final _remotePlayerProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) async {
      final api = ref.watch(runioApiProvider);
      if (api == null || !ref.watch(serverModeProvider)) return null;
      if (id == ref.read(gameProvider).user?.id) return null;
      try {
        return await api.player(id);
      } on ApiException {
        return null;
      }
    });

class _PlayerSheet extends ConsumerWidget {
  const _PlayerSheet({required this.playerId});

  static const _statSize = 22.0;

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final p = game.playerById(playerId);
    if (p == null) return const SizedBox(height: 120);
    final isMe = p.id == game.user?.id;
    final open = isMe || p.isPublic;
    final board = ref.watch(leaderboardProvider);
    final cellArea = ref.watch(cellAreaProvider);
    final miles = game.settings.useMiles;
    final place = ref.watch(homeStateProvider)?.name;
    final rank = board.indexWhere((e) => e.player.id == p.id) + 1;
    final remote = ref.watch(_remotePlayerProvider(p.id)).value;
    final serverMode = ref.watch(serverModeProvider);
    final cells =
        remote?['cells'] as int? ??
        ref.watch(territoryIndexProvider).countOf(p.id);
    final area = Fmt.area(cells * cellArea);
    final live = (ref.watch(liveRunnersProvider).value ?? const <LiveRunner>[])
        .where((r) => r.playerId == p.id)
        .firstOrNull;
    final following = game.following.contains(p.id);
    final color = Color(p.color);

    String trailLength(LiveRunner r) {
      var m = 0.0;
      for (var i = 1; i < r.trail.length; i++) {
        m += Geo.haversine(r.trail[i - 1].pos, r.trail[i].pos);
      }
      final d = Fmt.distance(m, miles: miles);
      return '${d.value} ${d.unit}';
    }

    final crew = game.crewByCode(p.crewId);
    final subtitle = [
      if (live != null) 'Running now',
      if (rank > 0) '#$rank${place == null ? '' : ' in $place'}',
      if (open && crew != null) crew.name,
      if (remote?['followsYou'] == true) 'Follows you',
      if (!open) 'Keeps their profile private',
    ].join('  ·  ');

    final stats = <Widget>[
      StatBlock(
        value: area.value,
        unit: area.unit,
        label: 'Territory',
        size: _statSize,
      ),
      StatBlock(
        value: rank == 0 ? '–' : '#$rank',
        label: 'Rank',
        size: _statSize,
      ),
      if (isMe) ...[
        StatBlock(value: '${game.kills}', label: 'Cuts', size: _statSize),
      ] else if (open && live != null)
        StatBlock(value: trailLength(live), label: 'Open trail')
      else
        StatBlock(value: '$cells', label: 'Hexes', size: _statSize),
    ];

    return SingleChildScrollView(
      // Clear the system buttons at the bottom.
      padding: EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.md,
        AppSpace.screen,
        AppSpace.xl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          FadeSlideIn(
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PlayerAvatar(
                      avatar: isMe ? p.avatar : p.shownAvatar,
                      seed: p.id,
                      color: color,
                      size: AppSize.avatarLg,
                    ),
                    if (live != null) const _LiveDot(size: 16),
                  ],
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? '${p.name} (you)' : p.shownName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(22),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.xs),
                        Text(subtitle, style: AppText.small),
                      ],
                      if (p.isRival) ...[
                        const SizedBox(height: AppSpace.sm),
                        const GhostBadge(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (p.isRival) ...[
            const SizedBox(height: AppSpace.lg),
            Text(
              'Ghost runners are simulated on your phone so there\'s always '
              'land to fight for. Their land is real to take, and they '
              'retreat as real runners join your area.',
              style: AppText.small,
            ),
          ],
          const SizedBox(height: AppSpace.xxl),
          FadeSlideIn(
            index: 1,
            child: Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.lg),
                  Expanded(child: stats[i]),
                ],
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(height: AppSpace.xl),
            FadeSlideIn(
              index: 2,
              child: Row(
                children: [
                  Expanded(
                    child: StatBlock(
                      value: '${game.runs.length}',
                      label: 'Runs',
                      size: _statSize,
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      value: Fmt.distance(
                        game.runs.fold(0.0, (a, r) => a + r.distanceM),
                        miles: miles,
                      ).value,
                      unit: miles ? 'mi' : 'km',
                      label: 'Distance',
                      size: _statSize,
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      value: '${game.deaths}',
                      label: 'Times cut',
                      size: _statSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.xxl),
          FadeSlideIn(
            index: 3,
            child: Row(
              children: [
                // Ghosts can't be followed once there are real runners.
                if (!isMe && open && !(serverMode && p.isRival)) ...[
                  Expanded(
                    child: following
                        ? OutlinedButton(
                            onPressed: () =>
                                ref.read(cloudSyncProvider).toggleFollow(p.id),
                            child: const Text('Following'),
                          )
                        : FilledButton(
                            onPressed: () =>
                                ref.read(cloudSyncProvider).toggleFollow(p.id),
                            child: const Text('Follow'),
                          ),
                  ),
                  const SizedBox(width: AppSpace.md),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showOnMap(context, ref, live),
                    icon: const Icon(AppIcons.location, size: AppSize.iconSm),
                    label: const Text('Map', maxLines: 1),
                  ),
                ),
              ],
            ),
          ),
          if (serverMode && !isMe && !p.isRival) ...[
            const SizedBox(height: AppSpace.md),
            FadeSlideIn(
              index: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _report(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Report'),
                  ),
                  const SizedBox(width: AppSpace.md),
                  TextButton(
                    onPressed: () => _block(context, ref, p.shownName),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Block'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Blocked runners can't follow you and show as anonymous to each other,
  /// on the map too. Undo it in Settings → Account.
  Future<void> _block(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block $name?', style: AppText.title(20)),
        content: Text(
          "You'll see each other as anonymous runners, and follows both ways "
          'are removed. They are not told.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _act(context, () async {
      await ref.read(runioApiProvider)!.block(playerId);
      final game = ref.read(gameProvider);
      ref
          .read(gameProvider.notifier)
          .setFollowing({...game.following}..remove(playerId));
    }, done: '$name is blocked');
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    const reasons = {
      'cheating': 'Cheating (fake GPS, driving)',
      'offensive_name': 'Offensive name',
      'offensive_avatar': 'Offensive photo',
      'harassment': 'Harassment',
      'other': 'Something else',
    };
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                0,
                AppSpace.screen,
                AppSpace.sm,
              ),
              child: Text('Why are you reporting?', style: AppText.section),
            ),
            for (final e in reasons.entries)
              ListTile(
                title: Text(e.value),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    await _act(
      context,
      () => ref.read(runioApiProvider)!.report(playerId, reason),
      done: "Thanks. We'll take a look.",
    );
  }

  Future<void> _act(
    BuildContext context,
    Future<void> Function() action, {
    required String done,
  }) async {
    String message;
    try {
      await action();
      message = done;
    } on ApiException catch (e) {
      message = e.message;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showOnMap(BuildContext context, WidgetRef ref, LiveRunner? live) {
    final game = ref.read(gameProvider);
    var target = live?.pos;
    if (target == null) {
      for (final e in game.owners.entries) {
        if (e.value == playerId) {
          target = ref.read(gridProvider).center(e.key);
          break;
        }
      }
    }
    Navigator.of(context).pop();
    if (target == null) return;
    ref.read(mapFocusProvider.notifier).focus(target);
    GoRouter.of(context).go('/map');
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Positioned(
    right: 0,
    bottom: 0,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.ok,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 3),
      ),
    ),
  );
}
