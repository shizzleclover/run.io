import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../app/theme/app_icons.dart';
import '../../core/avatars.dart';

/// Draws a player's avatar as a map icon: a disc with a ring in their
/// colour and a small pointer underneath. Returned as raw RGBA for
/// `style.addStyleImage`, at [pixelRatio] times [size].
Future<mb.MbxImage> renderAvatarMarker({
  required String? avatar,
  required String seed,
  required Color color,
  double size = 44,
  double pixelRatio = 3,
}) async {
  final px = size * pixelRatio;
  final ring = px * 0.08;
  final w = px.ceil();
  final h = (px * 1.18).ceil(); // room for the pointer

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final c = Offset(px / 2, px / 2);
  final r = px / 2;

  // Pointer.
  final tip = Path()
    ..moveTo(c.dx - r * 0.32, px * 0.9)
    ..lineTo(c.dx, h.toDouble() - 1)
    ..lineTo(c.dx + r * 0.32, px * 0.9)
    ..close();
  canvas.drawPath(tip, Paint()..color = color);

  // Ring.
  canvas.drawCircle(c, r, Paint()..color = color);

  // Inside.
  final inner = Rect.fromCircle(center: c, radius: r - ring);
  canvas.save();
  canvas.clipPath(Path()..addOval(inner));
  switch (AvatarSource.of(avatar, seed)) {
    case PhotoAvatar(:final file):
      final codec = await ui.instantiateImageCodec(
        await file.readAsBytes(),
        targetWidth: w,
      );
      final img = (await codec.getNextFrame()).image;
      paintImage(
        canvas: canvas,
        rect: inner,
        image: img,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    case PresetAvatar(:final preset):
      _iconDisc(canvas, inner, color, preset.icon, px);
    case AnonymousAvatar():
      _iconDisc(canvas, inner, kAnonymousGrey, AppIcons.anonymous, px);
  }
  canvas.restore();

  final image = await recorder.endRecording().toImage(w, math.max(h, w));
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return mb.MbxImage(
    width: image.width,
    height: image.height,
    data: bytes!.buffer.asUint8List(),
  );
}

/// Anonymous runners: one neutral colour, whatever their territory colour.
const kAnonymousGrey = Color(0xFF6B7078);

void _iconDisc(
  Canvas canvas,
  Rect inner,
  Color fill,
  IconData icon,
  double px,
) {
  canvas.drawRect(inner, Paint()..color = fill);
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: px * 0.5,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, inner.center - Offset(tp.width / 2, tp.height / 2));
}
