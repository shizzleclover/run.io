import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/geo.dart';

/// Draws a run's trail and the hexes it claimed, fitted to the canvas.
/// Used for the summary card, share image and run history thumbnails.
class TrailPainter extends CustomPainter {
  TrailPainter({
    required this.path,
    required this.cells,
    required this.color,
    this.strokeWidth = 3,
    this.padding = 16,
  });

  final List<LatLng> path;
  final List<List<LatLng>> cells;
  final Color color;
  final double strokeWidth;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    final all = <XY>[
      ...path.map(Geo.project),
      for (final c in cells) ...c.map(Geo.project),
    ];
    if (all.isEmpty) return;

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in all) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final dx = math.max(maxX - minX, 1.0);
    final dy = math.max(maxY - minY, 1.0);
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;
    final scale = math.min(w / dx, h / dy);
    final ox = padding + (w - dx * scale) / 2;
    final oy = padding + (h - dy * scale) / 2;

    // Mercator y goes up, canvas y goes down.
    Offset map(XY p) =>
        Offset(ox + (p.x - minX) * scale, oy + (maxY - p.y) * scale);

    final fill = Paint()..color = color.withValues(alpha: 0.22);
    final edge = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (final cell in cells) {
      final pts = cell.map((c) => map(Geo.project(c))).toList();
      final hex = Path()..addPolygon(pts, true);
      canvas.drawPath(hex, fill);
      canvas.drawPath(hex, edge);
    }

    if (path.length < 2) return;
    final line = Path();
    final first = map(Geo.project(path.first));
    line.moveTo(first.dx, first.dy);
    for (final p in path.skip(1)) {
      final o = map(Geo.project(p));
      line.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final end = map(Geo.project(path.last));
    canvas.drawCircle(end, strokeWidth * 1.8, Paint()..color = color);
    canvas.drawCircle(
      first,
      strokeWidth * 1.4,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(TrailPainter old) =>
      old.path != path || old.cells != cells || old.color != color;
}
