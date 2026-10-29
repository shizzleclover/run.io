import 'engine_config.dart';
import 'geo.dart';
import 'hex_grid.dart';

/// Ownership, indexed for the questions the app asks often: "how many
/// cells does each player have" and "which cells are in these regions".
///
/// Regions are cells of a coarse hex grid (~3 km). The backend will use the
/// same keys for loading territory and for live channels.
class TerritoryIndex {
  TerritoryIndex._(this.counts, this.byRegion);

  /// Build once per ownership change. O(cells).
  factory TerritoryIndex.build(
    Map<String, String> owners, {
    HexGrid grid = const HexGrid(),
    RegionGrid regions = const RegionGrid(),
  }) {
    final counts = <String, int>{};
    final byRegion = <String, List<String>>{};
    owners.forEach((cell, owner) {
      counts[owner] = (counts[owner] ?? 0) + 1;
      (byRegion[regions.regionOf(cell, grid)] ??= []).add(cell);
    });
    return TerritoryIndex._(counts, byRegion);
  }

  /// playerId -> number of cells.
  final Map<String, int> counts;

  /// regionId -> cells in it.
  final Map<String, List<String>> byRegion;

  int countOf(String playerId) => counts[playerId] ?? 0;

  Iterable<String> cellsIn(Iterable<String> regionIds) sync* {
    for (final r in regionIds) {
      yield* byRegion[r] ?? const [];
    }
  }
}

/// The coarse grid regions are cells of.
class RegionGrid {
  const RegionGrid({
    this.grid = const HexGrid(size: EngineConfig.regionSizeMercator),
  });

  final HexGrid grid;

  static final _cache = <String, String>{};

  /// The region a fine cell belongs to (by its centre).
  String regionOf(String cell, HexGrid fine) =>
      _cache[cell] ??= grid.cellAt(fine.center(cell));

  /// Regions covering roughly [radiusM] real meters around [p].
  List<String> around(LatLng p, double radiusM) {
    // Region size in real meters at this latitude, centre to corner.
    final regionM = grid.size * Geo.mercatorScale(p.lat);
    final k = (radiusM / (regionM * 1.5)).ceil() + 1;
    return grid.disk(grid.cellAt(p), k);
  }
}
