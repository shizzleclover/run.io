import 'dart:math' as math;

/// A geographic coordinate. Pure Dart, no Flutter or Mapbox imports.
class LatLng {
  const LatLng(this.lat, this.lng);

  final double lat;
  final double lng;

  List<double> toJson() => [lat, lng];

  factory LatLng.fromJson(List<dynamic> j) =>
      LatLng((j[0] as num).toDouble(), (j[1] as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'LatLng($lat, $lng)';
}

/// A point in Web Mercator meters.
class XY {
  const XY(this.x, this.y);
  final double x;
  final double y;
}

const double _earthRadius = 6378137.0;

class Geo {
  Geo._();

  /// Great-circle distance in meters.
  static double haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.lat)) *
            math.cos(_rad(b.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Move [meters] from [p] along [bearing] (radians, 0 = north, pi/2 = east).
  static LatLng offset(LatLng p, double meters, double bearing) {
    final dLat = meters * math.cos(bearing) / 111320.0;
    final dLng =
        meters * math.sin(bearing) / (111320.0 * math.cos(_rad(p.lat)));
    return LatLng(p.lat + dLat, p.lng + dLng);
  }

  static XY project(LatLng p) {
    final lat = math.max(-85.0, math.min(85.0, p.lat));
    return XY(
      _earthRadius * _rad(p.lng),
      _earthRadius * math.log(math.tan(math.pi / 4 + _rad(lat) / 2)),
    );
  }

  static LatLng unproject(XY p) {
    final lng = _deg(p.x / _earthRadius);
    final lat = _deg(2 * math.atan(math.exp(p.y / _earthRadius)) - math.pi / 2);
    return LatLng(lat, lng);
  }

  /// Real meters per Web Mercator meter at this latitude.
  static double mercatorScale(double lat) => math.cos(_rad(lat));

  /// Ray casting point-in-polygon. Polygon may or may not repeat first point.
  static bool pointInPolygon(XY p, List<XY> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i];
      final b = poly[j];
      final crosses =
          (a.y > p.y) != (b.y > p.y) &&
          p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x;
      if (crosses) inside = !inside;
    }
    return inside;
  }

  /// Intersection point of segments ab and cd, or null.
  static XY? segmentIntersection(XY a, XY b, XY c, XY d) {
    final rx = b.x - a.x, ry = b.y - a.y;
    final sx = d.x - c.x, sy = d.y - c.y;
    final denom = rx * sy - ry * sx;
    if (denom.abs() < 1e-9) return null;
    final t = ((c.x - a.x) * sy - (c.y - a.y) * sx) / denom;
    final u = ((c.x - a.x) * ry - (c.y - a.y) * rx) / denom;
    if (t < 0 || t > 1 || u < 0 || u > 1) return null;
    return XY(a.x + t * rx, a.y + t * ry);
  }

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;
}
