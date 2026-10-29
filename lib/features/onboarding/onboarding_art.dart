import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';

/// Which rule an onboarding illustration acts out.
enum OnboardingScene { welcome, loop, claim, cut }

/// A small looping animation of one game rule, drawn on a hex grid. Plays
/// only while [active], so swiped-away pages don't burn battery.
class OnboardingArt extends StatefulWidget {
  const OnboardingArt({
    super.key,
    required this.scene,
    required this.color,
    this.active = true,
  });

  final OnboardingScene scene;

  /// The player's chosen territory colour.
  final Color color;
  final bool active;

  @override
  State<OnboardingArt> createState() => _OnboardingArtState();
}

class _OnboardingArtState extends State<OnboardingArt>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(OnboardingArt old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        size: Size.infinite,
        painter: _ScenePainter(
          scene: widget.scene,
          t: _c.value,
          mine: widget.color,
          rival: _rivalFor(widget.color),
          grid: AppColors.border,
          danger: AppColors.danger,
          surface: AppColors.surface,
        ),
      ),
    ),
  );

  /// A rival colour that's never the player's own.
  static Color _rivalFor(Color mine) {
    final blue = Color(AppColors.playerColors[1]);
    return mine == blue ? Color(AppColors.playerColors[2]) : blue;
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.scene,
    required this.t,
    required this.mine,
    required this.rival,
    required this.grid,
    required this.danger,
    required this.surface,
  });

  final OnboardingScene scene;
  final double t;
  final Color mine;
  final Color rival;
  final Color grid;
  final Color danger;
  final Color surface;

  static final _sqrt3 = math.sqrt(3);

  late double _r;
  late Offset _o;

  @override
  void paint(Canvas canvas, Size size) {
    _r = size.width / 13;
    _o = Offset(size.width / 2, size.height / 2);

    _drawGrid(canvas, size);
    switch (scene) {
      case OnboardingScene.welcome:
        _welcome(canvas, size);
      case OnboardingScene.loop:
        _loop(canvas, size);
      case OnboardingScene.claim:
        _claim(canvas, size);
      case OnboardingScene.cut:
        _cut(canvas, size);
    }
  }

  // ---------- scenes ----------

  /// Three territories breathing gently, a runner circling yours.
  void _welcome(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    _fillCluster(canvas, const [
      (0, 0),
      (1, 0),
      (0, 1),
      (-1, 1),
      (-1, 0),
      (0, -1),
      (1, -1),
    ], mine.withValues(alpha: 0.35 + 0.15 * pulse));
    _fillCluster(canvas, const [
      (3, -2),
      (4, -2),
      (3, -1),
      (4, -3),
    ], rival.withValues(alpha: 0.3));
    _fillCluster(canvas, const [
      (-4, 2),
      (-3, 2),
      (-4, 3),
      (-3, 1),
    ], Color(AppColors.playerColors[4]).withValues(alpha: 0.3));

    final loop = _loopPath(_o, _r * 2.6);
    final m = loop.computeMetrics().first;
    final head = m.getTangentForOffset(m.length * t)!.position;
    _stroke(
      canvas,
      m.extractPath(0, m.length),
      mine.withValues(alpha: 0.25),
      3,
    );
    _runner(canvas, head);
  }

  /// The trail draws itself around a block and closes.
  void _loop(Canvas canvas, Size size) {
    final path = _loopPath(_o, _r * 3.2);
    final m = path.computeMetrics().first;
    final drawT = (t / 0.7).clamp(0.0, 1.0);
    final drawn = m.extractPath(0, m.length * drawT);
    final start = m.getTangentForOffset(0)!.position;

    if (drawT >= 1) {
      final fade = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
      canvas.drawPath(
        path,
        Paint()..color = mine.withValues(alpha: 0.18 * fade),
      );
    }
    _stroke(canvas, drawn, mine, 4);

    // Where the loop started: a ring that fills once it closes.
    canvas.drawCircle(
      start,
      7,
      Paint()
        ..color = drawT >= 1 ? mine : surface
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      start,
      7,
      Paint()
        ..color = mine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    if (drawT < 1) {
      _runner(canvas, m.getTangentForOffset(m.length * drawT)!.position);
    } else {
      final ring = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
      canvas.drawCircle(
        start,
        7 + 18 * ring,
        Paint()
          ..color = mine.withValues(alpha: 0.5 * (1 - ring))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// The closed loop's hexes fill in from the middle out, rival land
  /// included.
  void _claim(Canvas canvas, Size size) {
    final path = _loopPath(_o, _r * 3.2);
    final inside = <(int, int)>[];
    for (var q = -6; q <= 6; q++) {
      for (var r = -6; r <= 6; r++) {
        if (path.contains(_center(q, r))) inside.add((q, r));
      }
    }
    inside.sort(
      (a, b) => (_center(a.$1, a.$2) - _o).distance.compareTo(
        (_center(b.$1, b.$2) - _o).distance,
      ),
    );
    // A rival owns the right-hand side before you claim it.
    bool rivals((int, int) c) => _center(c.$1, c.$2).dx > _o.dx + _r * 1.2;

    final filled = (inside.length * (t / 0.65).clamp(0.0, 1.0)).round();
    for (var i = 0; i < inside.length; i++) {
      final c = inside[i];
      final taken = i < filled;
      final color = taken
          ? mine.withValues(alpha: 0.55)
          : rivals(c)
          ? rival.withValues(alpha: 0.4)
          : null;
      if (color != null) _hex(canvas, c.$1, c.$2, color);
    }
    _stroke(canvas, path, mine, 3);
  }

  /// Your trail leaves your land; a rival runs across it; everything
  /// you own is wiped.
  void _cut(Canvas canvas, Size size) {
    const home = [(-3, 2), (-2, 2), (-3, 3), (-2, 1), (-4, 3), (-3, 1)];
    final wiped = t > 0.55;
    final fade = wiped ? ((t - 0.55) / 0.2).clamp(0.0, 1.0) : 0.0;

    _fillCluster(canvas, home, mine.withValues(alpha: 0.5 * (1 - fade)));

    // Your open trail: out of your land and up to the right.
    final from = _center(-2, 1);
    final trail = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(
        from.dx + _r * 1.5,
        from.dy - _r * 4,
        from.dx + _r * 5,
        from.dy - _r * 4.5,
        from.dx + _r * 6.5,
        from.dy - _r * 2,
      );
    final tm = trail.computeMetrics().first;
    final shown = (t / 0.35).clamp(0.0, 1.0);
    final trailColor = Color.lerp(
      mine,
      danger,
      fade,
    )!.withValues(alpha: 1 - 0.8 * ((t - 0.75) / 0.25).clamp(0.0, 1.0));
    _stroke(canvas, tm.extractPath(0, tm.length * shown), trailColor, 4);
    if (!wiped) {
      _runner(canvas, tm.getTangentForOffset(tm.length * shown)!.position);
    }

    // The rival, running straight down across it.
    final cross = tm.getTangentForOffset(tm.length * 0.55)!.position;
    final top = Offset(cross.dx, size.height * 0.08);
    final bottom = Offset(cross.dx, size.height * 0.92);
    final rt = ((t - 0.25) / 0.45).clamp(0.0, 1.0);
    if (rt > 0) {
      final head = Offset.lerp(top, bottom, rt)!;
      _stroke(
        canvas,
        Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(head.dx, head.dy),
        rival,
        4,
      );
      _runner(canvas, head, color: rival);
    }

    // The cut.
    if (wiped) {
      final pop = Curves.easeOutBack.transform(fade);
      final s = 10 * pop;
      final x = Paint()
        ..color = danger
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(cross, 16 * pop, Paint()..color = surface);
      canvas.drawLine(cross - Offset(s, s), cross + Offset(s, s), x);
      canvas.drawLine(cross - Offset(s, -s), cross + Offset(s, -s), x);
    }
  }

  // ---------- helpers ----------

  Offset _center(int q, int r) =>
      _o + Offset(_r * (_sqrt3 * q + _sqrt3 / 2 * r), _r * 1.5 * r);

  Path _hexPath(Offset c, double radius) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 30);
      final v = c + Offset(radius * math.cos(a), radius * math.sin(a));
      i == 0 ? p.moveTo(v.dx, v.dy) : p.lineTo(v.dx, v.dy);
    }
    return p..close();
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var q = -8; q <= 8; q++) {
      for (var r = -6; r <= 6; r++) {
        final c = _center(q, r);
        if (c.dx < -_r || c.dx > size.width + _r) continue;
        if (c.dy < -_r || c.dy > size.height + _r) continue;
        canvas.drawPath(_hexPath(c, _r * 0.92), paint);
      }
    }
  }

  void _hex(Canvas canvas, int q, int r, Color color) => canvas.drawPath(
    _hexPath(_center(q, r), _r * 0.92),
    Paint()..color = color,
  );

  void _fillCluster(Canvas canvas, List<(int, int)> cells, Color color) {
    for (final (q, r) in cells) {
      _hex(canvas, q, r, color);
    }
  }

  /// A slightly irregular loop, like a real run around a block.
  Path _loopPath(Offset c, double radius) {
    const wobble = [1.0, 0.86, 1.08, 0.92, 1.04, 0.88];
    final pts = [
      for (var i = 0; i < 6; i++)
        c +
            Offset.fromDirection(
              -math.pi / 2 + i * math.pi / 3,
              radius * wobble[i],
            ),
    ];
    final p = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final mid = Offset.lerp(a, b, 0.5)!;
      p.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
    }
    final first = Offset.lerp(pts[0], pts[1], 0.5)!;
    p.quadraticBezierTo(pts[0].dx, pts[0].dy, first.dx, first.dy);
    return p..close();
  }

  void _stroke(Canvas canvas, Path p, Color color, double width) =>
      canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

  void _runner(Canvas canvas, Offset p, {Color? color}) {
    canvas.drawCircle(p, 9, Paint()..color = surface);
    canvas.drawCircle(p, 6.5, Paint()..color = color ?? mine);
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.t != t || old.scene != scene || old.mine != mine;
}
