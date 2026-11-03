import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/api/cards.dart';
import '../../core/areas.dart';
import '../../core/format.dart';
import '../../core/invite.dart';
import '../../shared/widgets/ghost_badge.dart';
import '../../shared/widgets/player_chip.dart';
import '../../shared/widgets/player_sheet.dart';
import '../../state/account.dart';
import '../../state/area.dart';
import '../../state/game_controller.dart';

enum _Scope { area, state, crews }

/// Your state's board from the server. Your area is drawn from the land
/// loaded around you, but a state is too big to load, so it's asked for.
final _serverStateBoardProvider = FutureProvider.autoDispose<List<LeaderEntry>>(
  (ref) async {
    final code = ref.watch(gameProvider.select((g) => g.homeState));
    if (code == null) return const [];
    final res =
        await ref
                .read(apiProvider)!
                .get('/leaderboards', query: {'scope': 'state', 'id': code})
            as Map<String, dynamic>;
    final me = ref.read(gameProvider).user;
    final entries = [
      for (final item in (res['items'] as List).cast<Map<String, dynamic>>())
        (
          player: playerFromCard(item['player'] as Map<String, dynamic>),
          cells: item['cells'] as int,
          areaM2: (item['areaM2'] as num).toDouble(),
        ),
    ];
    // So tapping a runner opens their card.
    ref.read(gameProvider.notifier).upsertPlayers([
      for (final e in entries) e.player,
    ]);
    return [
      for (final e in entries)
        LeaderEntry(e.player.id == me?.id ? me! : e.player, e.cells, e.areaM2),
    ];
  },
);

/// Your area first: a new runner ranks against the people around them,
/// where a top spot is within reach, not against a whole state.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  _Scope _scope = _Scope.area;

  @override
  Widget build(BuildContext context) {
    final area = ref.watch(areaProvider);
    final place = ref.watch(homeStateProvider)?.name;

    final subtitle = switch (_scope) {
      _Scope.area =>
        area?.name ??
            'Within ${(kNearbyAreaRadiusM / 1000).toStringAsFixed(0)} km '
                'of home',
      _Scope.state => place ?? 'Your state',
      _Scope.crews => 'Crews by their members\' land',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screen,
              AppSpace.xs,
              AppSpace.screen,
              0,
            ),
            child: Row(
              children: [
                _ScopeTab(
                  label: area?.short ?? 'Near you',
                  selected: _scope == _Scope.area,
                  onTap: () => setState(() => _scope = _Scope.area),
                ),
                const SizedBox(width: AppSpace.sm),
                _ScopeTab(
                  label: place ?? 'State',
                  selected: _scope == _Scope.state,
                  onTap: () => setState(() => _scope = _Scope.state),
                ),
                const SizedBox(width: AppSpace.sm),
                _ScopeTab(
                  label: 'Crews',
                  selected: _scope == _Scope.crews,
                  onTap: () => setState(() => _scope = _Scope.crews),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screen,
              AppSpace.md,
              AppSpace.screen,
              AppSpace.xs,
            ),
            child: Text(subtitle, style: AppText.small),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.base,
              child: switch (_scope) {
                _Scope.area => _PlayerList(
                  key: const ValueKey('area'),
                  entries: ref.watch(areaBoardProvider),
                  footer: const _GhostFooter(),
                ),
                _Scope.state => _PlayerList(
                  key: const ValueKey('state'),
                  entries: ref.watch(serverModeProvider)
                      ? ref.watch(_serverStateBoardProvider).value ?? const []
                      : ref.watch(leaderboardProvider),
                ),
                _Scope.crews => const _CrewList(key: ValueKey('crews')),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Flexible(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.text : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.small.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.bg : AppColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}

class _PlayerList extends ConsumerWidget {
  const _PlayerList({super.key, required this.entries, this.footer});

  final List<LeaderEntry> entries;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(gameProvider.select((g) => g.user?.id));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      itemCount: entries.length + (footer == null ? 0 : 1),
      separatorBuilder: (_, _) => const Divider(indent: 64, endIndent: 8),
      itemBuilder: (context, i) {
        if (i == entries.length) return footer!;
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
                  child: Row(
                    children: [
                      Flexible(
                        child: PlayerChip(
                          name: isMe
                              ? '${e.player.name} (you)'
                              : e.player.shownName,
                          style: AppText.body.copyWith(
                            fontWeight: isMe
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          color: color,
                          avatar: isMe ? e.player.avatar : e.player.shownAvatar,
                          seed: e.player.id,
                          avatarSize: 36,
                        ),
                      ),
                      if (e.player.isRival) ...[
                        const SizedBox(width: AppSpace.sm),
                        const GhostBadge(compact: true),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: area.value, style: AppText.number(16)),
                      TextSpan(text: ' ${area.unit}', style: AppText.unit(12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Says how much of the area ghosts hold, and how to push them out.
class _GhostFooter extends ConsumerWidget {
  const _GhostFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final share = ref.watch(ghostShareProvider);
    if (share.ghosts == 0) return const SizedBox.shrink();
    final area = ref.watch(areaProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, AppSpace.lg, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.ghost, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghost runners hold ${(share.fraction * 100).round()}% '
                  'of this area. They\'re simulated, and they retreat as '
                  'real runners join.',
                  style: AppText.small,
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => shareText(appInvite(area: area?.name)),
                  child: const Text('Invite runners'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewList extends ConsumerWidget {
  const _CrewList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(crewBoardProvider);
    final mine = ref.watch(gameProvider.select((g) => g.user?.crewId));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(indent: 64, endIndent: 8),
          _CrewRow(
            rank: i + 1,
            entry: entries[i],
            isMine: entries[i].crew.code == mine,
          ),
        ],
        if (mine == null) ...[
          const SizedBox(height: AppSpace.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Run with your club or friends. Crews add up their members\' '
              'land and take on other crews.',
              style: AppText.small,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              onPressed: () => context.push('/crew'),
              icon: const Icon(AppIcons.crew, size: AppSize.iconSm),
              label: const Text('Start or join a crew'),
            ),
          ),
        ],
      ],
    );
  }
}

class _CrewRow extends StatelessWidget {
  const _CrewRow({
    required this.rank,
    required this.entry,
    required this.isMine,
  });

  final int rank;
  final CrewEntry entry;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final area = Fmt.area(entry.areaM2);
    final n = entry.members.length;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: isMine ? () => context.push('/crew') : null,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isMine ? AppColors.surface : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                style: AppText.number(
                  17,
                  color: rank == 1 ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            ),
            CrewMark(entry: entry, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.crew.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(
                            fontWeight: isMine
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (entry.crew.ghost) ...[
                        const SizedBox(width: AppSpace.sm),
                        const GhostBadge(compact: true),
                      ],
                    ],
                  ),
                  Text(
                    isMine
                        ? 'Your crew · $n member${n == 1 ? '' : 's'}'
                        : '$n member${n == 1 ? '' : 's'}',
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: area.value, style: AppText.number(16)),
                  TextSpan(text: ' ${area.unit}', style: AppText.unit(12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A crew's badge: its initial on the colour of its biggest member.
class CrewMark extends ConsumerWidget {
  const CrewMark({super.key, required this.entry, this.size = 36});

  final CrewEntry entry;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(territoryIndexProvider);
    final lead = [...entry.members]
      ..sort((a, b) => index.countOf(b.id).compareTo(index.countOf(a.id)));
    final color = Color(lead.first.color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        entry.crew.name.characters.first.toUpperCase(),
        style: AppText.title(size * 0.45).copyWith(color: AppColors.onAccent),
      ),
    );
  }
}
