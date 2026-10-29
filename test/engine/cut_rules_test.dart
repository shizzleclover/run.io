import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runio/engine/cut_rules.dart';
import 'package:runio/engine/geo.dart';
import 'package:runio/engine/track_point.dart';

void main() {
  const rules = CutRules();
  const origin = LatLng(6.5244, 3.3792);
  final now = DateTime(2026, 10, 29, 7);

  /// A trail heading north, one point every 10 m, [ageMin] minutes old.
  List<TrackPoint> trail({int points = 20, int ageMin = 1}) => [
    for (var i = 0; i < points; i++)
      TrackPoint(
        lat: Geo.offset(origin, i * 10.0, 0).lat,
        lng: Geo.offset(origin, i * 10.0, 0).lng,
        accuracy: 5,
        timestamp: now.subtract(Duration(minutes: ageMin)),
      ),
  ];

  // A segment crossing the trail east-west, 50 m up.
  final mid = Geo.offset(origin, 50, 0);
  final from = Geo.offset(mid, 20, 3 * math.pi / 2);
  final to = Geo.offset(mid, 20, math.pi / 2);

  test('crossing a fresh open trail cuts it', () {
    expect(rules.cuts(from: from, to: to, trail: trail(), now: now), isTrue);
  });

  test('a trail older than the TTL is safe', () {
    expect(
      rules.cuts(from: from, to: to, trail: trail(ageMin: 20), now: now),
      isFalse,
    );
  });

  test('trail inside the owner\'s land is safe', () {
    expect(
      rules.cuts(
        from: from,
        to: to,
        trail: trail(),
        now: now,
        isSafe: (_) => true,
      ),
      isFalse,
    );
  });

  test('the newest points are not cuttable', () {
    // Cross between the last two points.
    final tip = Geo.offset(origin, 185, 0);
    expect(
      rules.cuts(
        from: Geo.offset(tip, 20, 3 * math.pi / 2),
        to: Geo.offset(tip, 20, math.pi / 2),
        trail: trail(),
        now: now,
      ),
      isFalse,
    );
  });

  test('running alongside is not a cut', () {
    final a = Geo.offset(origin, 8, math.pi / 2);
    final b = Geo.offset(a, 150, 0);
    expect(rules.cuts(from: a, to: b, trail: trail(), now: now), isFalse);
  });

  test('both phones need good GPS', () {
    expect(rules.cleanEnough(5, 10), isTrue);
    expect(rules.cleanEnough(5, 30), isFalse);
  });

  test('runners who start together are a group', () {
    TrackPoint start(LatLng p, int sec) => TrackPoint(
      lat: p.lat,
      lng: p.lng,
      accuracy: 5,
      timestamp: now.add(Duration(seconds: sec)),
    );
    final near = Geo.offset(origin, 10, 0);
    final far = Geo.offset(origin, 200, 0);
    expect(rules.sameGroup(start(origin, 0), start(near, 30)), isTrue);
    expect(rules.sameGroup(start(origin, 0), start(far, 30)), isFalse);
    expect(rules.sameGroup(start(origin, 0), start(near, 300)), isFalse);
  });

  test('hardcore wipe removes every cell of the cut player only', () {
    final next = rules.wipe({'a': 'me', 'b': 'me', 'c': 'rival'}, 'me');
    expect(next, {'c': 'rival'});
  });
}
