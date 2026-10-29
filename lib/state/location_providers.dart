import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/location/gps_source.dart';
import '../core/location/location_source.dart';
import '../core/location/sim_source.dart';
import '../engine/track_point.dart';
import 'game_controller.dart';

/// Flipped on by the run controller so GPS switches to background mode
/// (Android foreground service, iOS background updates) during a run.
class TrackingFlag extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final backgroundTrackingProvider = NotifierProvider<TrackingFlag, bool>(
  TrackingFlag.new,
);

/// One simulator for the whole app session.
final simSourceProvider = Provider<SimSource>((ref) {
  final home = ref.read(fallbackCenterProvider) ?? kDefaultCenter;
  final sim = SimSource(home);
  ref.onDispose(sim.dispose);
  return sim;
});

/// Real GPS or simulator, depending on the debug setting.
final locationSourceProvider = Provider<LocationSource>((ref) {
  final simMode = ref.watch(gameProvider.select((g) => g.settings.simMode));
  if (simMode) return ref.watch(simSourceProvider);
  return GpsSource(background: ref.watch(backgroundTrackingProvider));
});

/// The live stream of location points everything else listens to.
final positionProvider = StreamProvider<TrackPoint>(
  (ref) => ref.watch(locationSourceProvider).points,
);
