import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runio/engine/geo.dart';
import 'package:runio/engine/loop_detector.dart';

const _origin = LatLng(6.5244, 3.3792);

/// Walks a square of [side] meters, one point every [step] meters,
/// starting at the origin and heading north. [closeGap] meters are left
/// unwalked at the end.
List<LatLng> square(double side, {double step = 10, double closeGap = 0}) {
  final pts = <LatLng>[_origin];
  var p = _origin;
  final bearings = [0.0, math.pi / 2, math.pi, 3 * math.pi / 2];
  var walked = 0.0;
  final total = side * 4 - closeGap;
  for (final b in bearings) {
    for (var d = step; d <= side + 1e-6 && walked < total; d += step) {
      p = Geo.offset(p, step, b);
      walked += step;
      pts.add(p);
    }
  }
  return pts;
}

void main() {
  const detector = LoopDetector();

  test('a closed 100 m square is detected', () {
    final loop = detector.detect(square(100));
    expect(loop, isNotNull);
    // Closed ring: first point repeated at the end.
    expect(loop!.polygon.first, loop.polygon.last);
  });

  test('a loop shorter than the minimum length does not close', () {
    expect(detector.detect(square(40)), isNull); // 160 m < 200 m
  });

  test('a straight line never closes', () {
    final line = [
      for (var i = 0; i < 60; i++) Geo.offset(_origin, i * 10.0, 0),
    ];
    expect(detector.detect(line), isNull);
  });

  test('stopping within the close radius closes the loop', () {
    // Ends 20 m short of the start, inside the 25 m close radius.
    expect(detector.detect(square(100, closeGap: 20)), isNotNull);
  });

  test('stopping outside the close radius does not', () {
    expect(detector.detect(square(100, closeGap: 60)), isNull);
  });

  test('near-close hint fires between the close and hint radius', () {
    expect(detector.isNearClose(square(100, closeGap: 40)), isTrue);
    expect(detector.isNearClose(square(100, closeGap: 100)), isFalse);
  });

  test('crossing an earlier segment closes the loop', () {
    // Square, then carry on north across the first leg.
    final pts = square(100, closeGap: 10);
    pts.add(Geo.offset(pts.last, 20, 3 * math.pi / 2));
    expect(detector.detect(pts), isNotNull);
  });
}
