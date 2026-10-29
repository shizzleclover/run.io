import 'package:flutter_test/flutter_test.dart';
import 'package:runio/engine/geo.dart';
import 'package:runio/engine/hex_grid.dart';
import 'package:runio/engine/territory_index.dart';

void main() {
  const grid = HexGrid();
  const regions = RegionGrid();
  const here = LatLng(9.0579, 7.4951);

  test('counts cells per owner', () {
    final cells = grid.disk(grid.cellAt(here), 2);
    final owners = {
      for (var i = 0; i < cells.length; i++) cells[i]: i.isEven ? 'a' : 'b',
    };
    final index = TerritoryIndex.build(owners);
    expect(index.countOf('a') + index.countOf('b'), cells.length);
    expect(index.countOf('nobody'), 0);
  });

  test('cells near a point are found through the regions around it', () {
    final cell = grid.cellAt(here);
    final index = TerritoryIndex.build({cell: 'a'});
    expect(index.cellsIn(regions.around(here, 500)), contains(cell));
  });

  test('far away cells are not in the regions around a point', () {
    final far = grid.cellAt(const LatLng(6.5244, 3.3792)); // Lagos
    final index = TerritoryIndex.build({far: 'a'});
    expect(index.cellsIn(regions.around(here, 3000)), isEmpty);
  });
}
