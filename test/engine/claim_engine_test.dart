import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runio/engine/claim_engine.dart';
import 'package:runio/engine/geo.dart';
import 'package:runio/engine/hex_grid.dart';

const _origin = LatLng(6.5244, 3.3792);

/// A closed square ring of [side] meters with its south-west corner at
/// the origin.
List<LatLng> ring(double side) {
  final ne = Geo.offset(Geo.offset(_origin, side, 0), side, math.pi / 2);
  final nw = Geo.offset(_origin, side, 0);
  final se = Geo.offset(_origin, side, math.pi / 2);
  return [_origin, nw, ne, se, _origin];
}

void main() {
  const grid = HexGrid();
  const engine = ClaimEngine(grid);

  test('claiming empty land takes every cell inside', () {
    final r = engine.claim(polygon: ring(200), playerId: 'me', owners: {});
    expect(r.isEmpty, isFalse);
    expect(r.stolenFrom, isEmpty);
    expect(r.owners.values.toSet(), {'me'});
    expect(r.owners.length, r.cells.length);
  });

  test('a loop too small to hold the minimum cells claims nothing', () {
    final r = engine.claim(polygon: ring(15), playerId: 'me', owners: {});
    expect(r.isEmpty, isTrue);
    expect(r.owners, isEmpty);
  });

  test('cells owned by a rival are stolen and counted', () {
    final inside = grid.cellAt(
      Geo.offset(Geo.offset(_origin, 100, 0), 100, math.pi / 2),
    );
    final r = engine.claim(
      polygon: ring(200),
      playerId: 'me',
      owners: {inside: 'rival'},
    );
    expect(r.owners[inside], 'me');
    expect(r.stolenFrom, {'rival': 1});
    expect(r.cells, contains(inside));
  });

  test('your own cells are not re-counted', () {
    final first = engine.claim(polygon: ring(200), playerId: 'me', owners: {});
    final again = engine.claim(
      polygon: ring(200),
      playerId: 'me',
      owners: first.owners,
    );
    expect(again.cells, isEmpty);
    expect(again.owners, first.owners);
  });

  test('cells outside the loop are untouched', () {
    final far = grid.cellAt(Geo.offset(_origin, 2000, 0));
    final r = engine.claim(
      polygon: ring(200),
      playerId: 'me',
      owners: {far: 'rival'},
    );
    expect(r.owners[far], 'rival');
  });
}
