import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/live/presence.dart';
import '../engine/claim_engine.dart';
import '../engine/cut_rules.dart';
import '../engine/geo.dart';
import '../engine/territory_index.dart';
import '../engine/track_point.dart';
import 'game_controller.dart';

/// Rivals run on this phone, in real time, until there's a backend. It plays
/// the server's part too: it decides cuts and applies their result.
///
/// Up to two rivals at a time jog a loop out of their own land, about
/// 3 m/s. If they make it back, they claim what's inside (yours too).
/// Paper.io rules, hardcore: cross a rival's open trail and they're out
/// and lose all their land; let one cross yours and so are you.
class SimPresence implements PresenceService {
  SimPresence(this._ref) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final Ref _ref;
  final _rng = math.Random();
  final _runnersCtrl = StreamController<List<LiveRunner>>.broadcast();
  final _eventsCtrl = StreamController<LiveEvent>.broadcast();
  final _active = <String, _SimRunner>{};

  /// Cut rivals sit out until this time, then respawn with a little land.
  final _outUntil = <String, DateTime>{};
  late final Timer _timer;

  TrackPoint? _me;
  List<TrackPoint> _myTrail = const [];
  TrackPoint? _myStart;
  bool _running = false;

  static const _rules = CutRules();
  static const _regions = RegionGrid();
  static const _maxActive = 2;
  static const _speed = 3.0; // m/s
  static const _range = 1500.0; // only rivals this close to you spawn
  static const _respawnAfter = Duration(minutes: 3);
  static const _botAccuracy = 5.0;

  @override
  Stream<List<LiveRunner>> get runners => _runnersCtrl.stream;

  @override
  Stream<LiveEvent> get events => _eventsCtrl.stream;

  @override
  void publish({
    required TrackPoint pos,
    required List<TrackPoint> trail,
    required bool running,
    TrackPoint? runStart,
  }) {
    final prev = _me;
    _me = pos;
    _myTrail = trail;
    _running = running;
    _myStart = runStart;
    if (running && prev != null && prev.pos != pos.pos) _checkYouCut(prev, pos);
  }

  @override
  void publishIdle(LatLng pos) {
    if (_running) return;
    _me = TrackPoint(
      lat: pos.lat,
      lng: pos.lng,
      accuracy: _me?.accuracy ?? 10,
      timestamp: DateTime.now(),
    );
  }

  void _tick() {
    final me = _me;
    if (me == null) return;
    _respawnDue(me.pos);
    // More traffic while you run, so there's something to race.
    final spawnChance = _running ? 1 / 20 : 1 / 60;
    if (_active.length < _maxActive && _rng.nextDouble() < spawnChance) {
      _spawn(me.pos);
    }
    for (final r in [..._active.values]) {
      _advance(r);
    }
    _emit();
  }

  void _respawnDue(LatLng me) {
    final game = _ref.read(gameProvider);
    final index = _ref.read(territoryIndexProvider);
    final now = DateTime.now();
    for (final r in game.rivals) {
      if (_active.containsKey(r.id) || index.countOf(r.id) > 0) continue;
      final until = _outUntil[r.id];
      if (until == null) {
        // Landless when we got here (e.g. cut before a restart).
        _outUntil[r.id] = now.add(_respawnAfter);
      } else if (now.isAfter(until)) {
        _outUntil.remove(r.id);
        final spot = Geo.offset(
          me,
          600 + _rng.nextDouble() * 600,
          _rng.nextDouble() * 2 * math.pi,
        );
        _ref.read(gameProvider.notifier).respawnRival(r.id, spot);
      }
    }
  }

  void _spawn(LatLng me) {
    final game = _ref.read(gameProvider);
    final grid = _ref.read(gridProvider);
    final index = _ref.read(territoryIndexProvider);
    final idle = game.rivals
        .where(
          (r) =>
              !_active.containsKey(r.id) &&
              !_outUntil.containsKey(r.id) &&
              index.countOf(r.id) > 0,
        )
        .toList();
    if (idle.isEmpty) return;
    final rival = idle[_rng.nextInt(idle.length)];

    // Start from one of their cells near you, found through the region
    // index instead of scanning the whole map.
    final near = [
      for (final c in index.cellsIn(_regions.around(me, _range)))
        if (game.owners[c] == rival.id &&
            Geo.haversine(grid.center(c), me) < _range)
          c,
    ];
    if (near.isEmpty) return;
    final start = grid.center(near[_rng.nextInt(near.length)]);

    // A loop of 4 to 6 corners, 120 to 260 m out, leaning toward you.
    final towardMe = _bearing(start, me);
    final corners = 4 + _rng.nextInt(3);
    final radius = 120 + _rng.nextDouble() * 140;
    final hub = Geo.offset(start, radius, towardMe);
    final waypoints = <LatLng>[
      for (var i = 0; i < corners; i++)
        Geo.offset(
          hub,
          radius * (0.8 + _rng.nextDouble() * 0.4),
          towardMe + math.pi + i * 2 * math.pi / corners,
        ),
      start,
    ];
    _active[rival.id] = _SimRunner(
      rival.id,
      _point(start),
      _densify(start, waypoints),
    );
  }

  void _advance(_SimRunner r) {
    if (r.route.isEmpty) {
      _finish(r);
      return;
    }
    final prev = r.pos;
    r.pos = _point(r.route.removeAt(0));
    r.trail.add(r.pos);
    _checkCutYou(r, prev.pos, r.pos.pos);
  }

  /// A rival ran across your open trail.
  void _checkCutYou(_SimRunner r, LatLng from, LatLng to) {
    final me = _me;
    if (!_running || me == null) return;
    if (!_rules.cleanEnough(me.accuracy, _botAccuracy)) return;
    final start = _myStart;
    if (start != null && _rules.sameGroup(start, r.start)) return;
    final game = _ref.read(gameProvider);
    final myId = game.user?.id;
    if (!_rules.cuts(
      from: from,
      to: to,
      trail: _myTrail,
      now: DateTime.now(),
      isSafe: (p) => game.owners[_ref.read(gridProvider).cellAt(p)] == myId,
    )) {
      return;
    }
    _myTrail = const [];
    _running = false;
    _eventsCtrl.add(CutYou(r.id));
  }

  /// Your newest segment ran across a rival's open trail.
  void _checkYouCut(TrackPoint from, TrackPoint to) {
    if (!_rules.cleanEnough(to.accuracy, _botAccuracy)) return;
    final game = _ref.read(gameProvider);
    final grid = _ref.read(gridProvider);
    final now = DateTime.now();
    for (final r in [..._active.values]) {
      final start = _myStart;
      if (start != null && _rules.sameGroup(start, r.start)) continue;
      final hit = _rules.cuts(
        from: from.pos,
        to: to.pos,
        trail: r.trail,
        now: now,
        isSafe: (p) => game.owners[grid.cellAt(p)] == r.id,
      );
      if (!hit) continue;
      _active.remove(r.id);
      _outUntil[r.id] = now.add(_respawnAfter);
      _ref.read(gameProvider.notifier).youCut(r.id);
      _eventsCtrl.add(YouCut(r.id));
    }
    _emit();
  }

  void _finish(_SimRunner r) {
    _active.remove(r.id);
    if (r.trail.length < 4) return;
    final game = _ref.read(gameProvider);
    final result = ClaimEngine(_ref.read(gridProvider)).claim(
      polygon: [for (final t in r.trail) t.pos, r.trail.first.pos],
      playerId: r.id,
      owners: game.owners,
    );
    if (result.isEmpty) return;
    _ref.read(gameProvider.notifier).applyRivalClaim(result);
    final me = game.user?.id;
    _eventsCtrl.add(
      RivalClaimed(r.id, result.cells.length, result.stolenFrom[me] ?? 0),
    );
  }

  void _emit() {
    if (_runnersCtrl.isClosed) return;
    final now = DateTime.now();
    _runnersCtrl.add([
      for (final r in _active.values)
        LiveRunner(
          playerId: r.id,
          pos: r.pos.pos,
          trail: List.unmodifiable(r.trail),
          updatedAt: now,
        ),
    ]);
  }

  TrackPoint _point(LatLng p) => TrackPoint(
    lat: p.lat,
    lng: p.lng,
    accuracy: _botAccuracy,
    timestamp: DateTime.now(),
  );

  List<LatLng> _densify(LatLng from, List<LatLng> waypoints) {
    final out = <LatLng>[];
    var a = from;
    for (final b in waypoints) {
      final d = Geo.haversine(a, b);
      final steps = math.max(1, (d / _speed).ceil());
      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        out.add(
          LatLng(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t),
        );
      }
      a = b;
    }
    return out;
  }

  double _bearing(LatLng a, LatLng b) =>
      math.atan2(b.lng - a.lng, b.lat - a.lat);

  @override
  void dispose() {
    _timer.cancel();
    _runnersCtrl.close();
    _eventsCtrl.close();
  }
}

class _SimRunner {
  _SimRunner(this.id, this.start, this.route) : pos = start, trail = [start];
  final String id;

  /// Where and when this run began, for group immunity.
  final TrackPoint start;
  TrackPoint pos;
  final List<LatLng> route;
  final List<TrackPoint> trail;
}
