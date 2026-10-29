import '../../engine/geo.dart';
import '../../engine/track_point.dart';

/// Another runner, live on the map right now.
class LiveRunner {
  const LiveRunner({
    required this.playerId,
    required this.pos,
    required this.trail,
    required this.updatedAt,
  });

  final String playerId;
  final LatLng pos;

  /// Their open loop, with times: what closes into territory if they make
  /// it back, and what you can cut by running across it.
  final List<TrackPoint> trail;
  final DateTime updatedAt;
}

/// Something that happened between live runners.
sealed class LiveEvent {
  const LiveEvent(this.playerId);
  final String playerId;
}

/// [playerId] closed a loop and took [stolenFromYou] of your cells.
class RivalClaimed extends LiveEvent {
  const RivalClaimed(super.playerId, this.cells, this.stolenFromYou);
  final int cells;
  final int stolenFromYou;
}

/// You ran across [playerId]'s open loop. They're out, and (hardcore)
/// all their land is gone.
class YouCut extends LiveEvent {
  const YouCut(super.playerId);
}

/// [playerId] ran across your open loop. You're out, and all your land
/// is gone.
class CutYou extends LiveEvent {
  const CutYou(super.playerId);
}

/// Where live runners come from.
///
/// Today: [SimPresence] in lib/state, rivals run on this phone.
/// Later: a backend version (e.g. Supabase Realtime) publishes your
/// position and open loop, and streams everyone else's. The map and the
/// run screen only see this interface, so they won't change.
abstract class PresenceService {
  /// Everyone else who is out running near you.
  Stream<List<LiveRunner>> get runners;

  Stream<LiveEvent> get events;

  /// Your latest fix and open loop. Called about once a second during a
  /// run, and with [running] false when you stop. [runStart] is where and
  /// when this run began, for group-run immunity.
  void publish({
    required TrackPoint pos,
    required List<TrackPoint> trail,
    required bool running,
    TrackPoint? runStart,
  });

  /// Your position while you're not running, so runners near you show
  /// up. Ignored during a run, when [publish] is the source of truth.
  void publishIdle(LatLng pos);

  void dispose();
}
