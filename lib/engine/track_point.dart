import 'geo.dart';

/// One raw location reading, from real GPS or the simulator.
class TrackPoint {
  const TrackPoint({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.timestamp,
  });

  final double lat;
  final double lng;

  /// Horizontal accuracy in meters (lower is better).
  final double accuracy;
  final DateTime timestamp;

  LatLng get pos => LatLng(lat, lng);
}
