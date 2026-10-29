import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../state/game_controller.dart';
import '../../shared/motion/motion.dart';
import '../../state/stats.dart';
import '../../app/theme/app_icons.dart';

/// This week's goals and your streak. Tap to change the goals.
class WeekCard extends ConsumerWidget {
  const WeekCard({super.key});

  Future<void> _editGoals(BuildContext context, WidgetRef ref) async {
    final s = ref.read(gameProvider).settings;
    var km = s.weeklyDistanceGoalM / 1000;
    var runs = s.weeklyRunsGoal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Weekly goals', style: AppText.title(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Distance: ${km.round()} km', style: AppText.body),
              Slider(
                value: km,
                min: 2,
                max: 60,
                divisions: 29,
                label: '${km.round()} km',
                onChanged: (v) => setLocal(() => km = v),
              ),
              const SizedBox(height: 8),
              Text('Runs: $runs', style: AppText.body),
              Slider(
                value: runs.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: '$runs',
                onChanged: (v) => setLocal(() => runs = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    ref
        .read(gameProvider.notifier)
        .updateSettings(
          (s) => s.copyWith(
            weeklyDistanceGoalM: km.roundToDouble() * 1000,
            weeklyRunsGoal: runs,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekStatsProvider);
    final settings = ref.watch(gameProvider.select((g) => g.settings));
    final cellArea = ref.watch(cellAreaProvider);
    final dist = Fmt.distance(week.distanceM, miles: settings.useMiles);
    final goal = Fmt.distance(
      settings.weeklyDistanceGoalM,
      miles: settings.useMiles,
    );
    final area = Fmt.area(week.cells * cellArea);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('This week', style: AppText.section)),
            if (week.streak > 0)
              _Streak(days: week.streak, atRisk: !week.ranToday),
            IconButton(
              tooltip: 'Change weekly goals',
              visualDensity: VisualDensity.compact,
              icon: const Icon(AppIcons.edit, size: 18),
              color: AppColors.textMuted,
              onPressed: () => _editGoals(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _GoalBar(
          label: 'Distance',
          value: '${dist.value} / ${goal.value} ${goal.unit}',
          progress: week.distanceM / settings.weeklyDistanceGoalM,
        ),
        const SizedBox(height: 16),
        _GoalBar(
          label: 'Runs',
          value: '${week.runs} / ${settings.weeklyRunsGoal}',
          progress: week.runs / settings.weeklyRunsGoal,
        ),
        const SizedBox(height: 12),
        Text(
          'Claimed ${area.value} ${area.unit} this week',
          style: AppText.small,
        ),
      ],
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final done = progress >= 1;
    return Semantics(
      label: '$label $value${done ? ', goal reached' : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppText.body)),
              if (done)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    AppIcons.check,
                    size: 16,
                    color: AppColors.accent,
                  ),
                ),
              Text(
                value,
                style: AppText.number(15, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBar(progress: progress),
        ],
      ),
    );
  }
}

/// "🔥 5" in the section header. Amber when it's at risk today.
class _Streak extends StatelessWidget {
  const _Streak({required this.days, required this.atRisk});

  final int days;

  /// Haven't run yet today: run before midnight to keep it.
  final bool atRisk;

  @override
  Widget build(BuildContext context) {
    final c = atRisk ? AppColors.warning : AppColors.accent;
    return Tooltip(
      message: atRisk
          ? '$days-day streak. Run today to keep it.'
          : '$days-day streak. Safe for today.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.streak, size: 18, color: c),
          const SizedBox(width: 2),
          Text('$days', style: AppText.number(15, color: c)),
        ],
      ),
    );
  }
}
