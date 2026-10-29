import '../../engine/track_point.dart';

/// Where location comes from: real GPS, the simulator, or (later) GPX replay.
/// The game logic never knows which one it's talking to.
abstract class LocationSource {
  Stream<TrackPoint> get points;
  void dispose();
}
