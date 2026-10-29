import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/live/presence.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../engine/geo.dart';
import '../engine/track_point.dart';
import 'game_controller.dart';
import 'live_providers.dart';
import 'location_providers.dart';

/// Within this distance a runner counts as "nearby".
const kNearbyRadiusM = 150.0;

/// Watches live runners and sends "a potential friend is nearby".
///
/// Only when both of you are discoverable, you have alerts on, you don't
/// already follow them, and you haven't been told about them today. The
/// alert never says exactly where they are.
final nearbyWatcherProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<LiveRunner>>>(liveRunnersProvider, (_, next) {
    final runners = next.value;
    if (runners == null || runners.isEmpty) return;
    final me = switch (ref.read(positionProvider)) {
      AsyncData<TrackPoint>(:final value) => value.pos,
      _ => null,
    };
    if (me == null) return;

    final game = ref.read(gameProvider);
    final user = game.user;
    if (user == null || !user.discoverable || !game.settings.nearbyAlerts) {
      return;
    }
    final today = epochDay(DateTime.now());
    for (final r in runners) {
      final p = game.playerById(r.playerId);
      if (p == null ||
          !p.discoverable ||
          game.following.contains(p.id) ||
          game.nearbyAlerted[p.id] == today ||
          Geo.haversine(me, r.pos) > kNearbyRadiusM) {
        continue;
      }
      ref.read(gameProvider.notifier).markNearbyAlerted(p.id);
      Notifications.nearby(playerId: p.id, name: p.name);
    }
  });
});
