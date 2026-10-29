import 'dart:math' as math;

import 'engine_config.dart';
import 'geo.dart';

/// A pure-Dart hexagon grid laid over Web Mercator.
///
/// Cell ids are "q:r" axial coordinates. Same idea as Uber's H3, without
/// any native dependency, so it's fully testable and portable to a server.
class HexGrid {
  const HexGrid({this.size = EngineConfig.hexSizeMercator});

  /// Center-to-corner size in Web Mercator meters.
  final double size;

  static final double _sqrt3 = math.sqrt(3);

  static String id(int q, int r) => '$q:$r';

  static (int, int) parse(String id) {
    final parts = id.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  String cellAt(LatLng p) => _cellAtXY(Geo.project(p));

  String _cellAtXY(XY p) {
    final q = (_sqrt3 / 3 * p.x - p.y / 3) / size;
    final r = (2 / 3 * p.y) / size;
    return _round(q, r);
  }

  String _round(double q, double r) {
    final s = -q - r;
    var rq = q.roundToDouble();
    var rr = r.roundToDouble();
    final rs = s.roundToDouble();
    final dq = (rq - q).abs();
    final dr = (rr - r).abs();
    final ds = (rs - s).abs();
    if (dq > dr && dq > ds) {
      rq = -rr - rs;
    } else if (dr > ds) {
      rr = -rq - rs;
    }
    return id(rq.toInt(), rr.toInt());
  }

  XY _centerXY(int q, int r) =>
      XY(size * (_sqrt3 * q + _sqrt3 / 2 * r), size * 1.5 * r);

  LatLng center(String cell) {
    final (q, r) = parse(cell);
    return Geo.unproject(_centerXY(q, r));
  }

  /// The 6 corners of a cell. [inset] shrinks it toward the center (0..1),
  /// used to leave a thin gap between hexes on the map.
  List<LatLng> boundary(String cell, {double inset = 0}) {
    final (q, r) = parse(cell);
    final c = _centerXY(q, r);
    final s = size * (1 - inset);
    return List.generate(6, (i) {
      final a = math.pi / 180 * (60 * i - 30);
      return Geo.unproject(XY(c.x + s * math.cos(a), c.y + s * math.sin(a)));
    });
  }

  /// Every cell whose center falls inside [polygon].
  Set<String> cellsInPolygon(List<LatLng> polygon, {int maxCells = 50000}) {
    final result = <String>{};
    if (polygon.length < 3) return result;
    final pts = polygon.map(Geo.project).toList();

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }

    final rMin = ((2 / 3 * minY) / size).floor() - 1;
    final rMax = ((2 / 3 * maxY) / size).ceil() + 1;
    if (rMax - rMin > 4000) return result; // absurdly large loop, ignore

    for (var r = rMin; r <= rMax; r++) {
      final qMin = (minX / (size * _sqrt3) - r / 2).floor() - 1;
      final qMax = (maxX / (size * _sqrt3) - r / 2).ceil() + 1;
      for (var q = qMin; q <= qMax; q++) {
        if (Geo.pointInPolygon(_centerXY(q, r), pts)) {
          result.add(id(q, r));
          if (result.length >= maxCells) return result;
        }
      }
    }
    return result;
  }

  /// All cells within [k] steps of [cell], including itself.
  List<String> disk(String cell, int k) {
    final (q, r) = parse(cell);
    final out = <String>[];
    for (var dq = -k; dq <= k; dq++) {
      final lo = math.max(-k, -dq - k);
      final hi = math.min(k, -dq + k);
      for (var dr = lo; dr <= hi; dr++) {
        out.add(id(q + dq, r + dr));
      }
    }
    return out;
  }

  List<String> neighbors(String cell) => disk(cell, 1)..remove(cell);

  /// Real-world area of one cell at this latitude, in m².
  double cellAreaM2(double lat) {
    final s = size * Geo.mercatorScale(lat);
    return 3 * _sqrt3 / 2 * s * s;
  }
}
