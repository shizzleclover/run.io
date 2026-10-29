import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import 'game_controller.dart';

class WeekStats {
  const WeekStats({
    required this.distanceM,
    required this.runs,
    required this.cells,
    required this.streak,
    required this.ranToday,
  });

  /// Since Monday.
  final double distanceM;
  final int runs;
  final int cells;

  /// Days in a row with at least one run, ending today, or yesterday if
  /// you haven't run yet today (the streak isn't broken until midnight).
  final int streak;
  final bool ranToday;
}

final weekStatsProvider = Provider<WeekStats>((ref) {
  final runs = ref.watch(gameProvider.select((g) => g.runs));
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));

  var distance = 0.0;
  var count = 0;
  var cells = 0;
  for (final r in runs) {
    if (r.startedAt.isBefore(monday)) continue;
    distance += r.distanceM;
    count++;
    cells += r.cells.length;
  }

  final days = {for (final r in runs) epochDay(r.startedAt)};
  final today = epochDay(now);
  final ranToday = days.contains(today);
  var day = ranToday ? today : today - 1;
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day--;
  }

  return WeekStats(
    distanceM: distance,
    runs: count,
    cells: cells,
    streak: streak,
    ranToday: ranToday,
  );
});
