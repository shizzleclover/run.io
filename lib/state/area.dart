import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/areas.dart';
import '../core/models.dart';
import '../engine/geo.dart';
import '../engine/territory_index.dart';
import 'game_controller.dart';

/// The launch area you play in, or null outside every launch area.
final areaProvider = Provider<LaunchArea?>((ref) {
  final home = ref.watch(fallbackCenterProvider);
  return home == null ? null : areaAt(home);
});

/// "UI", or null when you're not in a launch area. For "#3 in UI".
final areaLabelProvider = Provider<String?>(
  (ref) => ref.watch(areaProvider)?.short,
);

/// Cells within your area: the launch area, else a few km around home.
final areaCellsProvider = Provider<Map<String, String>>((ref) {
  final home = ref.watch(fallbackCenterProvider);
  if (home == null) return const {};
  final area = ref.watch(areaProvider);
  final center = area?.center ?? home;
  final radius = area?.radiusM ?? kNearbyAreaRadiusM;
  final owners = ref.watch(gameProvider.select((g) => g.owners));
  final index = ref.watch(territoryIndexProvider);
  final grid = ref.watch(gridProvider);
  return {
    for (final cell in index.cellsIn(const RegionGrid().around(center, radius)))
      if (Geo.haversine(grid.center(cell), center) <= radius)
        cell: owners[cell]!,
  };
});

/// Ranked by land in your area. You're always on it, even with none.
final areaBoardProvider = Provider<List<LeaderEntry>>((ref) {
  final cells = ref.watch(areaCellsProvider);
  final game = ref.watch(gameProvider);
  final cellArea = ref.watch(cellAreaProvider);
  final counts = <String, int>{};
  for (final owner in cells.values) {
    counts[owner] = (counts[owner] ?? 0) + 1;
  }
  return [
    for (final p in game.players)
      if (counts.containsKey(p.id) || p.id == game.user?.id)
        LeaderEntry(p, counts[p.id] ?? 0, (counts[p.id] ?? 0) * cellArea),
  ]..sort((a, b) => b.cells.compareTo(a.cells));
});

class GhostShare {
  const GhostShare({
    required this.ghosts,
    required this.ghostCells,
    required this.claimedCells,
  });

  /// Ghost runners still holding land here.
  final int ghosts;
  final int ghostCells;
  final int claimedCells;

  /// Of the claimed land here, how much ghosts hold. 0 to 1.
  double get fraction => claimedCells == 0 ? 0 : ghostCells / claimedCells;
}

/// How much of your area is still held by ghosts.
final ghostShareProvider = Provider<GhostShare>((ref) {
  final cells = ref.watch(areaCellsProvider);
  final ghostIds = {
    for (final r in ref.watch(gameProvider.select((g) => g.activeRivals))) r.id,
  };
  final holding = <String>{};
  var ghostCells = 0;
  for (final owner in cells.values) {
    if (ghostIds.contains(owner)) {
      ghostCells++;
      holding.add(owner);
    }
  }
  return GhostShare(
    ghosts: holding.length,
    ghostCells: ghostCells,
    claimedCells: cells.length,
  );
});

class CrewEntry {
  const CrewEntry(this.crew, this.members, this.cells, this.areaM2);
  final Crew crew;

  /// Members on this phone. Until accounts, your crew is just you here.
  final List<Player> members;
  final int cells;
  final double areaM2;
}

/// Crews ranked by their members' land.
final crewBoardProvider = Provider<List<CrewEntry>>((ref) {
  final game = ref.watch(gameProvider);
  final index = ref.watch(territoryIndexProvider);
  final cellArea = ref.watch(cellAreaProvider);
  return [
    for (final crew in game.crews)
      if (game.players.where((p) => p.crewId == crew.code).toList()
          case final members when members.isNotEmpty)
        CrewEntry(
          crew,
          members,
          members.fold(0, (a, p) => a + index.countOf(p.id)),
          members.fold(0, (a, p) => a + index.countOf(p.id)) * cellArea,
        ),
  ]..sort((a, b) => b.cells.compareTo(a.cells));
});
