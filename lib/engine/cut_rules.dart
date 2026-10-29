import 'engine_config.dart';
import 'geo.dart';
import 'track_point.dart';

/// Paper.io cuts, hardcore: run across someone's open trail and they're
/// out, and lose all their land.
///
/// Only the part of a trail outside the owner's land, from the last
/// [trailTtl], is vulnerable. Pure Dart, so the server can run the exact
/// same rule later.
class CutRules {
  const CutRules({
    this.trailTtl = EngineConfig.trailTtl,
    this.maxAccuracy = EngineConfig.cutMaxAccuracyM,
    this.groupRadius = EngineConfig.groupRadiusM,
    this.groupWindow = EngineConfig.groupWindow,
    this.tipPoints = EngineConfig.cutTipPoints,
  });

  final Duration trailTtl;
  final double maxAccuracy;
  final double groupRadius;
  final Duration groupWindow;
  final int tipPoints;

  /// True if the segment [from]→[to] crosses a vulnerable part of [trail].
  ///
  /// [isSafe] says whether a point is inside the trail owner's land.
  bool cuts({
    required LatLng from,
    required LatLng to,
    required List<TrackPoint> trail,
    required DateTime now,
    bool Function(LatLng p)? isSafe,
  }) {
    final end = trail.length - 1 - tipPoints;
    if (end < 1) return false;
    final a = Geo.project(from);
    final b = Geo.project(to);
    for (var i = 0; i < end; i++) {
      final p = trail[i];
      final q = trail[i + 1];
      if (!_vulnerable(p, now, isSafe) && !_vulnerable(q, now, isSafe)) {
        continue;
      }
      if (Geo.segmentIntersection(
            Geo.project(p.pos),
            Geo.project(q.pos),
            a,
            b,
          ) !=
          null) {
        return true;
      }
    }
    return false;
  }

  bool _vulnerable(TrackPoint p, DateTime now, bool Function(LatLng)? isSafe) =>
      now.difference(p.timestamp) <= trailTtl &&
      !(isSafe?.call(p.pos) ?? false);

  /// Both phones knew where they were well enough to call it.
  bool cleanEnough(double accuracyA, double accuracyB) =>
      accuracyA <= maxAccuracy && accuracyB <= maxAccuracy;

  /// Started together (a group run): they can't cut each other.
  bool sameGroup(TrackPoint startA, TrackPoint startB) =>
      startA.timestamp.difference(startB.timestamp).abs() <= groupWindow &&
      Geo.haversine(startA.pos, startB.pos) <= groupRadius;

  /// Hardcore: the cut player loses every cell. It goes neutral.
  Map<String, String> wipe(Map<String, String> owners, String playerId) => {
    for (final e in owners.entries)
      if (e.value != playerId) e.key: e.value,
  };
}
