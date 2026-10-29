import 'engine_config.dart';
import 'geo.dart';

class LoopResult {
  const LoopResult(this.polygon);

  /// Closed ring of the loop (first point repeated at the end).
  final List<LatLng> polygon;
}

/// Finds closed loops in the current trail.
///
/// Two ways to close a loop:
/// 1. The newest segment crosses an older part of the trail.
/// 2. You come back within [closeRadius] of an earlier point.
/// Either way the loop must be at least [minLoopLength] long, which stops
/// GPS jitter at a traffic light from "closing" tiny fake loops.
class LoopDetector {
  const LoopDetector({
    this.closeRadius = EngineConfig.closeRadiusM,
    this.minLoopLength = EngineConfig.minLoopLengthM,
    this.nearRadius = EngineConfig.nearCloseRadiusM,
  });

  final double closeRadius;
  final double minLoopLength;
  final double nearRadius;

  LoopResult? detect(List<LatLng> trail) {
    final n = trail.length;
    if (n < 4) return null;

    final cum = _cumulative(trail);
    final total = cum[n - 1];
    if (total < minLoopLength) return null;

    final xy = trail.map(Geo.project).toList();
    final a = xy[n - 2];
    final b = xy[n - 1];

    // 1. Self-intersection. Earliest crossing gives the biggest loop.
    for (var i = 0; i <= n - 4; i++) {
      if (total - cum[i + 1] < minLoopLength) break;
      final hit = Geo.segmentIntersection(xy[i], xy[i + 1], a, b);
      if (hit != null) {
        final ring = <XY>[hit, ...xy.sublist(i + 1, n - 1), hit];
        return LoopResult(ring.map(Geo.unproject).toList());
      }
    }

    // 2. Came back close to an earlier point.
    final end = trail[n - 1];
    for (var j = 0; j < n - 2; j++) {
      if (total - cum[j] < minLoopLength) break;
      if (Geo.haversine(trail[j], end) <= closeRadius) {
        return LoopResult([...trail.sublist(j), trail[j]]);
      }
    }
    return null;
  }

  /// True when the runner is close (but not yet close enough) to closing.
  bool isNearClose(List<LatLng> trail) {
    final n = trail.length;
    if (n < 4) return false;
    final cum = _cumulative(trail);
    final total = cum[n - 1];
    if (total < minLoopLength) return false;
    final end = trail[n - 1];
    for (var j = 0; j < n - 2; j++) {
      if (total - cum[j] < minLoopLength) break;
      if (Geo.haversine(trail[j], end) <= nearRadius) return true;
    }
    return false;
  }

  List<double> _cumulative(List<LatLng> trail) {
    final cum = List<double>.filled(trail.length, 0);
    for (var i = 1; i < trail.length; i++) {
      cum[i] = cum[i - 1] + Geo.haversine(trail[i - 1], trail[i]);
    }
    return cum;
  }
}
