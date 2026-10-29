import 'dart:math' as math;

import 'geo.dart';
import 'hex_grid.dart';

/// Fake rivals so the map is never empty in the no-backend version.
class RivalSeeder {
  const RivalSeeder(this.grid);

  final HexGrid grid;

  /// Give each rival 2 to 3 organic blobs within ~1.5km of [center].
  Map<String, String> seed({
    required LatLng center,
    required List<String> rivalIds,
    required math.Random rng,
  }) {
    final owners = <String, String>{};
    for (final id in rivalIds) {
      final blobs = 2 + rng.nextInt(2);
      for (var b = 0; b < blobs; b++) {
        final dist = 300 + rng.nextDouble() * 1200;
        final bearing = rng.nextDouble() * 2 * math.pi;
        final origin = grid.cellAt(Geo.offset(center, dist, bearing));
        final k = 2 + rng.nextInt(3);
        for (final c in grid.disk(origin, k)) {
          // Drop some edge cells so blobs look organic, not perfect hexagons.
          if (c == origin || rng.nextDouble() < 0.82) {
            owners.putIfAbsent(c, () => id);
          }
        }
      }
    }
    return owners;
  }

  /// Daily growth: each rival takes a few cells on its frontier.
  /// It can take yours. That's the point: something to take back.
  ///
  /// With [targets] (your cells), rivals usually grow from the edge
  /// nearest your land instead of a random edge. Cells in [weak] (your
  /// stale land) are taken first. Rivals in [angry] (you raided them)
  /// grow twice as much.
  Map<String, String> expand({
    required Map<String, String> owners,
    required List<String> rivalIds,
    required math.Random rng,
    int maxPerRival = 6,
    Set<String> targets = const {},
    Set<String> weak = const {},
    Set<String> angry = const {},
    double aggression = 0.7,
  }) {
    final next = Map<String, String>.of(owners);
    final targetXY = [for (final t in targets) grid.center(t)];
    for (final id in rivalIds) {
      final mine = [
        for (final e in next.entries)
          if (e.value == id) e.key,
      ];
      final frontier = mine
          .where((c) => grid.neighbors(c).any((n) => next[n] != id))
          .toList();
      if (frontier.isEmpty) continue;

      var origin = frontier[rng.nextInt(frontier.length)];
      if (targetXY.isNotEmpty && rng.nextDouble() < aggression) {
        origin = _closestTo(frontier, targetXY);
      }
      final limit = angry.contains(id) ? maxPerRival * 2 : maxPerRival;
      final ring = grid.disk(origin, angry.contains(id) ? 3 : 2)
        ..shuffle(rng)
        // Stale cells first.
        ..sort(
          (a, b) => (weak.contains(b) ? 1 : 0) - (weak.contains(a) ? 1 : 0),
        );
      var taken = 0;
      for (final c in ring) {
        if (taken >= limit) break;
        if (next[c] == id) continue;
        next[c] = id;
        taken++;
      }
    }
    return next;
  }

  String _closestTo(List<String> cells, List<LatLng> targets) {
    var best = cells.first;
    var bestD = double.infinity;
    for (final c in cells) {
      final p = grid.center(c);
      for (final t in targets) {
        final d = Geo.haversine(p, t);
        if (d < bestD) {
          bestD = d;
          best = c;
        }
      }
    }
    return best;
  }
}
