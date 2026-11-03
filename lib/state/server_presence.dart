import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/cards.dart';
import '../core/areas.dart';
import '../core/env.dart';
import '../core/live/presence.dart';
import '../core/notifications.dart';
import '../engine/geo.dart';
import '../engine/territory_index.dart';
import '../engine/track_point.dart';
import 'account.dart';
import 'game_controller.dart';

/// The live map from the server: territory for where you are, everyone
/// running nearby, and the server's word on every claim and cut.
///
/// Same interface as [SimPresence], so the map and run screens don't
/// change. The phone still draws your claims at once; the server's answer
/// arrives a moment later and wins.
class ServerPresence implements PresenceService {
  ServerPresence(this._ref) {
    _connect();
    final home = _ref.read(fallbackCenterProvider);
    if (home != null) _maybeRefocus(home);
  }

  final Ref _ref;
  final _runnersCtrl = StreamController<List<LiveRunner>>.broadcast();
  final _eventsCtrl = StreamController<LiveEvent>.broadcast();
  final _runners = <String, LiveRunner>{};

  WebSocket? _socket;
  Timer? _reconnect;
  var _backoff = const Duration(seconds: 2);
  bool _disposed = false;

  /// Regions loaded and subscribed to, and the point they're around.
  Set<String> _regions = {};
  LatLng? _center;

  // The run being streamed.
  String? _runId;
  final _batch = <TrackPoint>[];
  final _runPoints = <TrackPoint>[];
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastIdle = DateTime.fromMillisecondsSinceEpoch(0);

  /// Part of this run never reached the server (no signal). At the end
  /// the whole run is sent for the server to replay.
  bool _gap = false;

  static const _regionGrid = RegionGrid();
  static const _batchEvery = Duration(seconds: 3);

  ApiClient get _api => _ref.read(apiProvider)!;
  GameController get _game => _ref.read(gameProvider.notifier);
  String? get _me => _ref.read(gameProvider).user?.id;

  @override
  Stream<List<LiveRunner>> get runners => _runnersCtrl.stream;

  @override
  Stream<LiveEvent> get events => _eventsCtrl.stream;

  // ---------- publishing ----------

  @override
  void publish({
    required TrackPoint pos,
    required List<TrackPoint> trail,
    required bool running,
    TrackPoint? runStart,
  }) {
    _maybeRefocus(pos.pos);
    if (running && _runId == null) {
      _runId = 'run-${DateTime.now().microsecondsSinceEpoch}';
      _runPoints.clear();
      _batch.clear();
      _gap = _socket == null;
      _send({'type': 'run.start', 'runId': _runId});
    }
    if (!running) {
      if (_runId != null) _endRun();
      return;
    }
    if (_runPoints.isEmpty || _runPoints.last.timestamp != pos.timestamp) {
      _runPoints.add(pos);
      _batch.add(pos);
    }
    if (DateTime.now().difference(_lastSent) >= _batchEvery) _flush();
  }

  @override
  void publishIdle(LatLng pos) {
    _maybeRefocus(pos);
    if (_runId != null || _socket == null) return;
    if (DateTime.now().difference(_lastIdle) < const Duration(minutes: 1)) {
      return;
    }
    _lastIdle = DateTime.now();
    _send({'type': 'idle', 'lat': pos.lat, 'lng': pos.lng});
  }

  void _flush() {
    final runId = _runId;
    if (runId == null || _batch.isEmpty) return;
    _lastSent = DateTime.now();
    final sent = _send({
      'type': 'pos',
      'runId': runId,
      'pts': [
        for (final p in _batch)
          [p.timestamp.millisecondsSinceEpoch, p.lat, p.lng, p.accuracy],
      ],
    });
    if (!sent) _gap = true;
    _batch.clear();
  }

  void _endRun() {
    _flush();
    _send({'type': 'run.end', 'runId': _runId});
    _runId = null;
    if (_gap && _runPoints.length >= 4) {
      // Loops closed without signal still count: the server replays them.
      final points = [
        for (final p in _runPoints)
          [p.timestamp.millisecondsSinceEpoch, p.lat, p.lng, p.accuracy],
      ];
      unawaited(_replay(points));
    }
    _runPoints.clear();
    _gap = false;
  }

  /// Runs still waiting to be replayed (no signal when they ended).
  final _pendingReplays = <List<List<num>>>[];

  Future<void> _replay(List<List<num>> points) async {
    try {
      await _api.post('/claims', {'points': points});
      await _loadTerritory(_regions);
    } on ApiException catch (e) {
      // Still offline: try again once the socket is back.
      if (e.code == 'offline') _pendingReplays.add(points);
      debugPrint('offline claims: $e');
    }
  }

  // ---------- territory ----------

  /// Loads the land around you: your whole launch area when you're in
  /// one, else a few km. Again only when you've moved a fair way.
  void _maybeRefocus(LatLng pos) {
    final area = areaAt(pos);
    final center = area?.center ?? pos;
    if (_center != null && Geo.haversine(_center!, center) < 1000) return;
    _center = center;
    final regions = _regionGrid
        .around(center, area == null ? 2500 : area.radiusM + 300)
        .toSet();
    _regions = regions;
    _send({'type': 'region.sub', 'regions': regions.toList()});
    _loadTerritory(regions);
  }

  Future<void> _loadTerritory(Set<String> regions) async {
    if (regions.isEmpty) return;
    try {
      final res =
          await _api.get('/territory', query: {'regions': regions.join(',')})
              as Map<String, dynamic>;
      final cards = (res['players'] as Map<String, dynamic>).values
          .cast<Map<String, dynamic>>();
      final cells = <String, String>{};
      final stale = <String>{};
      for (final c in res['cells'] as List) {
        final row = c as List;
        cells[row[0] as String] = row[1] as String;
        if (row[2] == 1) stale.add(row[0] as String);
      }
      _game.applyServerTerritory(
        regionIds: regions,
        cells: cells,
        stale: stale,
        players: [for (final c in cards) playerFromCard(c)],
        crews: [for (final c in cards) ?crewFromCard(c)],
      );
    } on ApiException catch (e) {
      debugPrint('territory: $e');
    }
  }

  // ---------- socket ----------

  Uri get _socketUrl {
    final base = Uri.parse(Env.apiUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path.replaceAll(RegExp(r'/$'), '')}/v1/live',
      queryParameters: {
        'token': _ref.read(sessionStoreProvider).current?.accessToken ?? '',
      },
    );
  }

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      final socket = await WebSocket.connect(
        _socketUrl.toString(),
      ).timeout(const Duration(seconds: 15));
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _backoff = const Duration(seconds: 2);
      socket.pingInterval = const Duration(seconds: 25);
      socket.listen(
        (data) => _onMessage(data as String),
        onDone: _onClosed,
        onError: (_) => _onClosed(),
        cancelOnError: true,
      );
      if (_regions.isNotEmpty) {
        _send({'type': 'region.sub', 'regions': _regions.toList()});
        _loadTerritory(_regions);
      }
      // Back within a minute: the server picks the run back up.
      if (_runId != null) _send({'type': 'run.start', 'runId': _runId});
      final pending = [..._pendingReplays];
      _pendingReplays.clear();
      for (final points in pending) {
        unawaited(_replay(points));
      }
    } on WebSocketException {
      // Most likely an expired token: any API call refreshes it.
      try {
        await _api.get('/me');
      } catch (_) {}
      _scheduleReconnect();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onClosed() {
    _socket = null;
    if (_runId != null) _gap = true;
    _runners.clear();
    _emitRunners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnect?.cancel();
    _reconnect = Timer(_backoff, _connect);
    final next = _backoff * 2;
    _backoff = next > const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : next;
  }

  bool _send(Map<String, dynamic> msg) {
    final socket = _socket;
    if (socket == null) return false;
    socket.add(jsonEncode(msg));
    return true;
  }

  void _onMessage(String raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final player = msg['player'] as String?;
    final card = msg['card'] as Map<String, dynamic>?;
    if (card != null && card['id'] != _me) {
      _game.upsertPlayers([playerFromCard(card)], crews: [?crewFromCard(card)]);
    }
    final me = _me;

    switch (msg['type']) {
      case 'runner.update':
        if (player == null || player == me) return;
        final pts = [for (final p in msg['pts'] as List) _point(p as List)];
        final prev = _runners[player];
        final trail = msg['reset'] == true || prev == null
            ? pts
            : [...prev.trail, ...pts];
        _runners[player] = LiveRunner(
          playerId: player,
          pos: _point(msg['pos'] as List).pos,
          trail: trail,
          updatedAt: DateTime.now(),
        );
        _emitRunners();

      case 'runner.leave':
        if (_runners.remove(player) != null) _emitRunners();

      case 'cells.claimed':
        if (player == null) return;
        final cells = List<String>.from(msg['cells'] as List);
        final owners = _ref.read(gameProvider).owners;
        final fromMe = cells.where((c) => owners[c] == me).length;
        _game.applyServerClaim(player, cells);
        if (player != me) {
          _eventsCtrl.add(RivalClaimed(player, cells.length, fromMe));
        }

      case 'cells.lost':
        _game.applyServerLoss(List<String>.from(msg['cells'] as List));

      case 'cut':
        final victim = msg['victim'] as String?;
        if (_runners.remove(victim) != null) _emitRunners();

      case 'you.cut':
        if (player == null) return;
        _runners.remove(player);
        _emitRunners();
        _game.youCut(player);
        _eventsCtrl.add(YouCut(player));

      case 'you.wereCut':
        // The run controller ends the run, wipes your land and benches you.
        if (player != null) _eventsCtrl.add(CutYou(player));

      case 'nearby' || 'ghost.near':
        if (player == null) return;
        final game = _ref.read(gameProvider);
        final p = game.playerById(player);
        if (p == null || !game.settings.nearbyAlerts) return;
        Notifications.nearby(
          playerId: p.id,
          name: p.shownName,
          ghost: msg['type'] == 'ghost.near',
        );

      case 'event':
        final title = msg['title'] as String?;
        final body = msg['body'] as String?;
        // Cuts and claims already show on the map as they happen.
        const shownLive = {'cut', 'you_cut', 'land_taken', 'friend_nearby'};
        if (title != null && body != null && !shownLive.contains(msg['kind'])) {
          Notifications.message(title: title, body: body, playerId: player);
        }

      case 'error':
        debugPrint('live: ${msg['code']} ${msg['message']}');
    }
  }

  TrackPoint _point(List p) => TrackPoint(
    lat: (p[0] as num).toDouble(),
    lng: (p[1] as num).toDouble(),
    accuracy: 5,
    timestamp: DateTime.fromMillisecondsSinceEpoch(p[2] as int),
  );

  void _emitRunners() {
    if (!_runnersCtrl.isClosed) _runnersCtrl.add(_runners.values.toList());
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnect?.cancel();
    _socket?.close();
    _runnersCtrl.close();
    _eventsCtrl.close();
  }
}
