import 'package:flutter_test/flutter_test.dart';
import 'package:runio/engine/geo.dart';
import 'package:runio/engine/hex_grid.dart';

void main() {
  const grid = HexGrid();

  test('a cell centre maps back to the same cell', () {
    final cell = grid.cellAt(const LatLng(9.0579, 7.4951));
    expect(grid.cellAt(grid.center(cell)), cell);
  });

  test('a cell has six distinct neighbours', () {
    final cell = grid.cellAt(const LatLng(4.8156, 7.0498));
    final n = grid.neighbors(cell);
    expect(n.toSet().length, 6);
    expect(n, isNot(contains(cell)));
  });

  test('disk(k) has 3k(k+1)+1 cells', () {
    for (var k = 0; k <= 4; k++) {
      expect(grid.disk('0:0', k).length, 3 * k * (k + 1) + 1);
    }
  });

  test('cell area near the equator is a few thousand m²', () {
    final a = grid.cellAreaM2(6.5);
    expect(a, greaterThan(1500));
    expect(a, lessThan(3000));
  });
}
