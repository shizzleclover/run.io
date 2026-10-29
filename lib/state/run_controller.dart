import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/live/presence.dart';
import '../core/models.dart';
import '../engine/claim_engine.dart';
import '../engine/geo.dart';
import '../engine/loop_detector.dart';
import '../engine/point_filter.dart';
import '../engine/track_point.dart';
import 'game_controller.dart';
import 'live_providers.dart';
import 'location_providers.dart';

enum RunStatus { idle, running, paused }

/// Fired every time a loop closes and claims land.
class ClaimEvent {
  const ClaimEvent({
    required this.id,
    required this.cells,
    required this.stolenFrom,
  });

  final int id;
  final Set<String> cells;
  final Map<String, int> stolenFrom;
}

class RunState {
  const RunState({
    this.status = RunStatus.idle,
    this.startedAt,
    this.elapsed = Duration.zero,
    this.distanceM = 0,
    this.trail = const [],
    this.path = const [],
    this.claimedCells = const {},
    this.stolenFrom = const {},
    this.lastClaim,
    this.nearClose = false,
    this.weakGps = false,
    this.autoPaused = false,
    this.splits = const [],
    this.finished,
  });

  final RunStatus status;
  final DateTime? startedAt;
  final Duration elapsed;
  final double distanceM;

  /// The open loop since the last claim. This is what can close.
  final List<LatLng> trail;

  /// Everything run so far.
  final List<LatLng> path;
  final Set<String> claimedCells;
  final Map<String, int> stolenFrom;
  final ClaimEvent? lastClaim;
  final bool nearClose;
  final bool weakGps;

  /// Stopped moving: the clock is paused, the loop stays open.
  final bool autoPaused;

  /// Moving seconds for each completed km (or mile).
  final List<int> splits;

  /// Set right after stopping, so the UI can open the summary.
  final RunRecord? finished;

  bool get isActive => status != RunStatus.idle;
  int get stolenTotal => stolenFrom.values.fold(0, (a, b) => a + b);

  RunState copyWith({
    RunStatus? status,
    Duration? elapsed,
    double? distanceM,
    List<LatLng>? trail,
    List<LatLng>? path,
    Set<String>? claimedCells,
    Map<String, int>? stolenFrom,
    ClaimEvent? lastClaim,
    bool? nearClose,
    bool? weakGps,
    bool? autoPaused,
    List<int>? splits,
  }) => RunState(
    status: status ?? this.status,
    startedAt: startedAt,
    elapsed: elapsed ?? this.elapsed,
    distanceM: distanceM ?? this.distanceM,
    trail: trail ?? this.trail,
    path: path ?? this.path,
    claimedCells: claimedCells ?? this.claimedCells,
    stolenFrom: stolenFrom ?? this.stolenFrom,
    lastClaim: lastClaim ?? this.lastClaim,
    nearClose: nearClose ?? this.nearClose,
    weakGps: weakGps ?? this.weakGps,
    autoPaused: autoPaused ?? this.autoPaused,
    splits: splits ?? this.splits,
    finished: finished,
  );
}

final runProvider = NotifierProvider<RunController, RunState>(
  RunController.new,
);

class RunController extends Notifier<RunState> {
  static const _filter = PointFilter();
  static const _detector = LoopDetector();

  TrackPoint? _last;
  Timer? _timer;
  DateTime? _segmentStart;
  Duration _banked = Duration.zero;
  int _claimSeq = 0;
  int _ticks = 0;
  DateTime? _lastMoveAt;

  /// The open loop with timestamps, for cuts (only fresh trail counts).
  /// Kept in step with [RunState.trail].
  List<TrackPoint> _timedTrail = const [];

  /// First good fix of this run, for group-run immunity.
  TrackPoint? _runStart;

  /// Cells you ran through, to keep your own land fresh.
  final _visited = <String>{};

  static const _autoPauseAfter = Duration(seconds: 12);

  double get _splitUnitM =>
      ref.read(gameProvider).settings.useMiles ? 1609.344 : 1000;

  PresenceService get _presence => ref.read(presenceProvider);

  @override
  RunState build() {
    ref.listen<AsyncValue<TrackPoint>>(positionProvider, (_, next) {
      if (next case AsyncData(:final value)) _onPoint(value);
    });
    // Someone ran across your open trail. Paper.io, hardcore: you're out.
    ref.listen<AsyncValue<LiveEvent>>(liveEventsProvider, (_, next) {
      if (next case AsyncData(value: CutYou(:final playerId))) {
        if (state.isActive) _end(cutBy: playerId);
      }
    });
    ref.onDispose(() => _timer?.cancel());
    return const RunState();
  }

  // ---------- controls ----------

  /// Seconds left of the cooldown after being cut, or null if you can run.
  Duration? get cooldownLeft {
    final until = ref.read(gameProvider).cooldownUntil;
    final left = until?.difference(DateTime.now());
    return left == null || left.isNegative ? null : left;
  }

  void start() {
    if (state.isActive || cooldownLeft != null) return;
    final settings = ref.read(gameProvider).settings;
    if (settings.keepScreenOn) WakelockPlus.enable();
    ref.read(backgroundTrackingProvider.notifier).set(true);

    _last = null;
    _banked = Duration.zero;
    _segmentStart = DateTime.now();
    _lastMoveAt = DateTime.now();
    _ticks = 0;
    _visited.clear();
    _timedTrail = const [];
    _runStart = null;
    state = RunState(status: RunStatus.running, startedAt: DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    if (state.status != RunStatus.running) return;
    if (!state.autoPaused) _banked += DateTime.now().difference(_segmentStart!);
    // Paused runners aren't out on the map: no trail to cut.
    final last = _last;
    if (last != null) {
      _presence.publish(pos: last, trail: const [], running: false);
    }
    _last = null;
    _timedTrail = const [];
    // A pause breaks the loop: no closing across a bus ride.
    state = state.copyWith(
      status: RunStatus.paused,
      elapsed: _banked,
      trail: const [],
      nearClose: false,
      autoPaused: false,
    );
  }

  void resume() {
    if (state.status != RunStatus.paused) return;
    _segmentStart = DateTime.now();
    _lastMoveAt = DateTime.now();
    state = state.copyWith(status: RunStatus.running);
  }

  void stop() => _end();

  /// Ends the run. With [cutBy], someone cut your trail: the run is saved
  /// whatever its length, and you lose all your land.
  void _end({String? cutBy}) {
    if (!state.isActive) return;
    if (state.status == RunStatus.running && !state.autoPaused) {
      _banked += DateTime.now().difference(_segmentStart!);
    }
    _timer?.cancel();
    _timer = null;

    final game = ref.read(gameProvider.notifier);
    RunRecord? record;
    if (cutBy != null ||
        state.distanceM >= 20 ||
        state.claimedCells.isNotEmpty) {
      record = _snapshot(recovered: false, cutBy: cutBy);
      game.addRun(record);
    }

    if (cutBy != null) {
      game.youWereCut();
    } else {
      game.touch(_visited);
    }
    final last = _last;
    if (last != null) {
      _presence.publish(pos: last, trail: const [], running: false);
    }
    _timedTrail = const [];

    ref.read(repositoryProvider).clearActiveRun();
    WakelockPlus.disable();
    ref.read(backgroundTrackingProvider.notifier).set(false);
    _last = null;
    state = RunState(finished: record);
  }

  /// Called when the summary sheet closes.
  void dismissSummary() {
    if (state.finished != null) state = const RunState();
  }

  // ---------- internals ----------

  RunRecord _snapshot({required bool recovered, String? cutBy}) => RunRecord(
    id: (state.startedAt ?? DateTime.now()).microsecondsSinceEpoch.toString(),
    startedAt: state.startedAt ?? DateTime.now(),
    endedAt: DateTime.now(),
    distanceM: state.distanceM,
    movingSeconds: _banked.inSeconds,
    path: state.path,
    cells: state.claimedCells.toList(),
    stolenFrom: state.stolenFrom,
    recovered: recovered,
    splits: state.splits,
    cutBy: cutBy,
  );

  void _tick() {
    if (state.status != RunStatus.running) return;
    final now = DateTime.now();

    // Standing still (traffic light, danfo stop): stop the clock, but keep
    // the loop open so you can carry on and close it.
    if (!state.autoPaused &&
        ref.read(gameProvider).settings.autoPause &&
        now.difference(_lastMoveAt ?? now) > _autoPauseAfter) {
      final moving = _lastMoveAt!.difference(_segmentStart!);
      if (!moving.isNegative) _banked += moving;
      state = state.copyWith(autoPaused: true, elapsed: _banked);
    }
    if (state.autoPaused) return;

    final elapsed = _banked + now.difference(_segmentStart!);
    state = state.copyWith(elapsed: elapsed);

    // Crash safety: snapshot the run every 15 seconds.
    if (++_ticks % 15 == 0) {
      ref.read(repositoryProvider).saveActiveRun(_snapshot(recovered: true));
    }
  }

  void _onPoint(TrackPoint p) {
    if (state.status != RunStatus.running) return;

    switch (_filter.check(_last, p)) {
      case FilterVerdict.badAccuracy:
        if (!state.weakGps) state = state.copyWith(weakGps: true);
        return;
      case FilterVerdict.tooFast:
        // In a vehicle. Keep following, but break the loop.
        _last = p;
        _timedTrail = [p];
        state = state.copyWith(
          trail: [p.pos],
          nearClose: false,
          weakGps: false,
        );
        return;
      case FilterVerdict.jitter:
        if (state.weakGps) state = state.copyWith(weakGps: false);
        return;
      case FilterVerdict.accept:
        break;
    }

    final step = _last == null ? 0.0 : Geo.haversine(_last!.pos, p.pos);
    _last = p;
    _runStart ??= p;

    final now = DateTime.now();
    _lastMoveAt = now;
    if (state.autoPaused) {
      _segmentStart = now;
      state = state.copyWith(autoPaused: false);
    }
    _visited.add(ref.read(gridProvider).cellAt(p.pos));

    // Splits: one entry per full km (or mile).
    var splits = state.splits;
    final distance = state.distanceM + step;
    if ((distance / _splitUnitM).floor() > splits.length) {
      final moving = (_banked + now.difference(_segmentStart!)).inSeconds;
      final before = splits.fold(0, (a, b) => a + b);
      splits = [...splits, moving - before];
    }

    var trail = [...state.trail, p.pos];
    _timedTrail = [..._timedTrail, p];
    final path = [...state.path, p.pos];
    var claimed = state.claimedCells;
    var stolen = state.stolenFrom;
    var event = state.lastClaim;

    final game = ref.read(gameProvider);
    final loop = game.user == null ? null : _detector.detect(trail);
    if (loop != null) {
      final result = ClaimEngine(ref.read(gridProvider)).claim(
        polygon: loop.polygon,
        playerId: game.user!.id,
        owners: game.owners,
      );
      if (!result.isEmpty) {
        ref.read(gameProvider.notifier).applyClaim(result);
        claimed = {...claimed, ...result.cells};
        stolen = Map<String, int>.of(stolen);
        result.stolenFrom.forEach((k, v) => stolen[k] = (stolen[k] ?? 0) + v);
        event = ClaimEvent(
          id: ++_claimSeq,
          cells: result.cells,
          stolenFrom: result.stolenFrom,
        );
      }
      // Start the next loop from here.
      trail = [p.pos];
      _timedTrail = [p];
    }

    state = state.copyWith(
      trail: trail,
      path: path,
      distanceM: distance,
      claimedCells: claimed,
      stolenFrom: stolen,
      lastClaim: event,
      nearClose: _detector.isNearClose(trail),
      weakGps: false,
      splits: splits,
    );
    _publish();
  }

  void _publish() {
    final last = _last;
    if (last == null) return;
    _presence.publish(
      pos: last,
      trail: _timedTrail,
      running: state.status == RunStatus.running,
      runStart: _runStart,
    );
  }
}
