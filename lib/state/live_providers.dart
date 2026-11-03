import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/live/presence.dart';
import 'location_providers.dart';
import 'account.dart';
import 'server_presence.dart';
import 'sim_presence.dart';

/// The live layer: the server when you're signed in, otherwise ghosts
/// simulated on this phone.
final presenceProvider = Provider<PresenceService>((ref) {
  final PresenceService service = ref.watch(serverModeProvider)
      ? ServerPresence(ref)
      : SimPresence(ref);
  ref.onDispose(service.dispose);
  // While you're not running, still say where you are, so runners near
  // you show up. During a run the run controller publishes instead.
  ref.listen(positionProvider, (_, next) {
    if (next case AsyncData(:final value)) {
      service.publishIdle(value.pos);
    }
  });
  return service;
});

final liveRunnersProvider = StreamProvider<List<LiveRunner>>(
  (ref) => ref.watch(presenceProvider).runners,
);

final liveEventsProvider = StreamProvider<LiveEvent>(
  (ref) => ref.watch(presenceProvider).events,
);
