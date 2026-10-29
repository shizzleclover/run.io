import 'engine_config.dart';
import 'geo.dart';
import 'hex_grid.dart';

class ClaimResult {
  const ClaimResult({
    required this.cells,
    required this.stolenFrom,
    required this.owners,
  });

  /// Cells that changed hands to the player in this claim.
  final Set<String> cells;

  /// ownerId -> number of cells taken from them.
  final Map<String, int> stolenFrom;

  /// The full ownership map after the claim.
  final Map<String, String> owners;

  bool get isEmpty => cells.isEmpty;
}

/// The whole game rule in one pure function:
/// (loop polygon, current owners) -> (new owners).
///
/// No Flutter, no DB, no Mapbox. This exact file can move to a server later.
class ClaimEngine {
  const ClaimEngine(this.grid, {this.minCells = EngineConfig.minClaimCells});

  final HexGrid grid;
  final int minCells;

  ClaimResult claim({
    required List<LatLng> polygon,
    required String playerId,
    required Map<String, String> owners,
  }) {
    final interior = grid.cellsInPolygon(polygon);
    if (interior.length < minCells) {
      return ClaimResult(cells: const {}, stolenFrom: const {}, owners: owners);
    }

    // The loop line itself counts too, like Paper.io.
    final cells = {...interior, ...polygon.map(grid.cellAt)};

    final next = Map<String, String>.of(owners);
    final changed = <String>{};
    final stolen = <String, int>{};

    for (final c in cells) {
      final prev = next[c];
      if (prev == playerId) continue;
      if (prev != null) stolen[prev] = (stolen[prev] ?? 0) + 1;
      next[c] = playerId;
      changed.add(c);
    }

    return ClaimResult(cells: changed, stolenFrom: stolen, owners: next);
  }
}
