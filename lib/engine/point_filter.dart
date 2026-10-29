import 'engine_config.dart';
import 'geo.dart';
import 'track_point.dart';

enum FilterVerdict { accept, badAccuracy, tooFast, jitter }

/// Decides whether a GPS point is usable.
class PointFilter {
  const PointFilter({
    this.maxAccuracy = EngineConfig.maxAccuracyM,
    this.maxSpeed = EngineConfig.maxSpeedMps,
    this.minStep = EngineConfig.minStepM,
  });

  final double maxAccuracy;
  final double maxSpeed;
  final double minStep;

  FilterVerdict check(TrackPoint? last, TrackPoint next) {
    if (next.accuracy > maxAccuracy) return FilterVerdict.badAccuracy;
    if (last == null) return FilterVerdict.accept;

    final d = Geo.haversine(last.pos, next.pos);
    if (d < minStep) return FilterVerdict.jitter;

    final dt = next.timestamp.difference(last.timestamp).inMilliseconds / 1000;
    if (dt <= 0) return FilterVerdict.jitter;
    if (d / dt > maxSpeed) return FilterVerdict.tooFast;

    return FilterVerdict.accept;
  }
}
