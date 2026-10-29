import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runio/engine/geo.dart';
import 'package:runio/engine/hex_grid.dart';
import 'package:runio/engine/rival_seeder.dart';

void main() {
  const grid = HexGrid();
  const seeder = RivalSeeder(grid);
  const center = LatLng(9.0579, 7.4951);

  test('seeding gives every rival some land', () {
    final owners = seeder.seed(
      center: center,
      rivalIds: ['r1', 'r2'],
      rng: math.Random(1),
    );
    expect(owners.values.toSet(), {'r1', 'r2'});
  });

  test('expanding grows rivals and never shrinks them', () {
    final rng = math.Random(2);
    final owners = seeder.seed(center: center, rivalIds: ['r1'], rng: rng);
    final next = seeder.expand(owners: owners, rivalIds: ['r1'], rng: rng);
    final before = owners.values.where((o) => o == 'r1').length;
    final after = next.values.where((o) => o == 'r1').length;
    expect(after, greaterThan(before));
  });

  test('an angry rival grows more than a calm one', () {
    final owners = seeder.seed(
      center: center,
      rivalIds: ['r1'],
      rng: math.Random(3),
    );
    int grown(Set<String> angry) {
      final next = seeder.expand(
        owners: owners,
        rivalIds: ['r1'],
        rng: math.Random(4),
        angry: angry,
      );
      return next.values.where((o) => o == 'r1').length;
    }

    expect(grown({'r1'}), greaterThan(grown({})));
  });
}
