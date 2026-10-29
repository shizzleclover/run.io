import 'package:flutter_test/flutter_test.dart';
import 'package:runio/engine/geo.dart';
import 'package:runio/engine/point_filter.dart';
import 'package:runio/engine/track_point.dart';

void main() {
  const filter = PointFilter();
  final t0 = DateTime(2026, 1, 1, 6);
  const start = LatLng(6.5244, 3.3792);

  TrackPoint at(LatLng p, int seconds, {double accuracy = 5}) => TrackPoint(
    lat: p.lat,
    lng: p.lng,
    accuracy: accuracy,
    timestamp: t0.add(Duration(seconds: seconds)),
  );

  test('first good point is accepted', () {
    expect(filter.check(null, at(start, 0)), FilterVerdict.accept);
  });

  test('poor accuracy is rejected before anything else', () {
    expect(
      filter.check(null, at(start, 0, accuracy: 40)),
      FilterVerdict.badAccuracy,
    );
  });

  test('tiny moves are jitter', () {
    final next = Geo.offset(start, 1, 0);
    expect(filter.check(at(start, 0), at(next, 1)), FilterVerdict.jitter);
  });

  test('running pace is accepted', () {
    final next = Geo.offset(start, 4, 0); // 4 m/s
    expect(filter.check(at(start, 0), at(next, 1)), FilterVerdict.accept);
  });

  test('vehicle speed is too fast', () {
    final next = Geo.offset(start, 15, 0); // 15 m/s, ~54 km/h
    expect(filter.check(at(start, 0), at(next, 1)), FilterVerdict.tooFast);
  });

  test('non-increasing timestamps are treated as jitter', () {
    final next = Geo.offset(start, 10, 0);
    expect(filter.check(at(start, 5), at(next, 5)), FilterVerdict.jitter);
  });
}
