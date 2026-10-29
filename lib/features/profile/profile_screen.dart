import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../shared/widgets/avatar_picker.dart';
import '../../shared/widgets/player_avatar.dart';
import '../../shared/widgets/stat_block.dart';
import '../../shared/widgets/trail_painter.dart';
import '../../state/game_controller.dart';
import '../../app/theme/app_icons.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Your name', style: AppText.title(20)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) ref.read(gameProvider.notifier).rename(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final cellArea = ref.watch(cellAreaProvider);
    final user = game.user;
    if (user == null) return const Scaffold();
    final color = Color(user.color);
    final miles = game.settings.useMiles;

    final myCells = game.owners.values.where((o) => o == user.id).length;
    final area = Fmt.area(myCells * cellArea);
    final totalDist = Fmt.distance(
      game.runs.fold(0.0, (a, r) => a + r.distanceM),
      miles: miles,
    );
    final stolen = game.runs.fold(0, (a, r) => a + r.stolenTotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(AppIcons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Header
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Change avatar',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showAvatarPicker(
                      context,
                      current: user.avatar,
                      seed: user.id,
                      color: color,
                    );
                    if (picked != null) {
                      ref.read(gameProvider.notifier).setAvatar(picked);
                    }
                  },
                  child: Stack(
                    children: [
                      PlayerAvatar(
                        avatar: user.avatar,
                        seed: user.id,
                        color: color,
                        size: 64,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.bg, width: 2),
                          ),
                          child: const Icon(
                            AppIcons.camera,
                            size: 12,
                            color: AppColors.onAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  user.name,
                  style: AppText.title(22),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(AppIcons.edit, size: 20),
                color: AppColors.textMuted,
                onPressed: () => _rename(context, ref, user.name),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 12),
          Text('Territory colour', style: AppText.label),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final c in AppColors.playerColors)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Semantics(
                    button: true,
                    selected: c == user.color,
                    label: 'Territory colour',
                    child: GestureDetector(
                      onTap: () => ref.read(gameProvider.notifier).recolor(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 34,
                        height: 34,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == user.color
                                ? AppColors.text
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // One quiet panel of six numbers, split by hairlines, instead of
          // six separate boxes.
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                _StatRow(
                  StatBlock(value: area.value, unit: area.unit, label: 'Owned'),
                  StatBlock(value: '${game.runs.length}', label: 'Runs'),
                ),
                const Divider(indent: 16, endIndent: 16),
                _StatRow(
                  StatBlock(
                    value: totalDist.value,
                    unit: totalDist.unit,
                    label: 'Distance',
                  ),
                  StatBlock(value: '$stolen', label: 'Hexes stolen'),
                ),
                const Divider(indent: 16, endIndent: 16),
                _StatRow(
                  StatBlock(value: '${game.kills}', label: 'Cuts'),
                  StatBlock(value: '${game.deaths}', label: 'Times cut'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          Text('Run history', style: AppText.section),
          const SizedBox(height: 12),
          if (game.runs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No runs yet. Hit Start and go claim something.',
                style: AppText.bodyMuted,
                textAlign: TextAlign.center,
              ),
            ),
          for (final r in game.runs)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => context.push('/profile/run/${r.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: CustomPaint(
                          painter: TrailPainter(
                            path: r.path,
                            cells: const [],
                            color: color,
                            strokeWidth: 1.6,
                            padding: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Fmt.dateTime(r.startedAt),
                              style: AppText.body.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${Fmt.distance(r.distanceM, miles: miles).value} '
                              '${Fmt.distance(r.distanceM, miles: miles).unit}'
                              '  ·  ${Fmt.duration(Duration(seconds: r.movingSeconds))}'
                              '${r.recovered ? '  ·  recovered' : ''}',
                              style: AppText.small,
                            ),
                          ],
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: Fmt.area(r.cells.length * cellArea).value,
                              style: AppText.number(16),
                            ),
                            TextSpan(
                              text:
                                  ' ${Fmt.area(r.cells.length * cellArea).unit}',
                              style: AppText.unit(11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.left, this.right);
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    child: Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    ),
  );
}
