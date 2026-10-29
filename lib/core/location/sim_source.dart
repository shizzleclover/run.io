import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import '../../engine/geo.dart';
import '../../engine/track_point.dart';
import 'location_source.dart';

/// Fake GPS for testing at your desk. Tap the map and the "runner" jogs
/// there at ~3.5 m/s, sped up 4x so you're not waiting around.
class SimSource implements LocationSource {
  SimSource(LatLng start) : _pos = start {
    _ctrl = StreamController<TrackPoint>.broadcast(
      onListen: () => scheduleMicrotask(_emit),
    );
  }

  static const double stepMeters = 3.5; // one simulated second at jog pace
  static const Duration tick = Duration(milliseconds: 250); // 4x speed

  late final StreamController<TrackPoint> _ctrl;
  final _queue = ListQueue<LatLng>();
  LatLng _pos;
  DateTime _clock = DateTime.now();
  Timer? _timer;

  LatLng get position => _pos;

  @override
  Stream<TrackPoint> get points => _ctrl.stream;

  void moveTo(LatLng target) {
    final from = _queue.isNotEmpty ? _queue.last : _pos;
    final dist = Geo.haversine(from, target);
    final steps = math.max(1, (dist / stepMeters).ceil());
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      _queue.add(
        LatLng(
          from.lat + (target.lat - from.lat) * t,
          from.lng + (target.lng - from.lng) * t,
        ),
      );
    }
    _timer ??= Timer.periodic(tick, (_) => _step());
  }

  void stop() {
    _queue.clear();
    _timer?.cancel();
    _timer = null;
  }

  void _step() {
    if (_queue.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _pos = _queue.removeFirst();
    _emit();
  }

  void _emit() {
    if (_ctrl.isClosed) return;
    _clock = _clock.add(const Duration(seconds: 1));
    _ctrl.add(
      TrackPoint(lat: _pos.lat, lng: _pos.lng, accuracy: 5, timestamp: _clock),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.close();
  }
}
