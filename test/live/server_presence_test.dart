// Runs against a real backend, so it's skipped unless one is up:
//   cd backend && PORT=8097 JOBS_ENABLED=false PUBLIC_URL=http://localhost:8097 \
//     DATABASE_URL=postgres://runio:runio@localhost:5432/runio_test \
//     node --env-file=.env dist/server.js > /tmp/runio-api.log &
//   RUNIO_MAIL_LOG=/tmp/runio-api.log flutter test test/live \
//     --dart-define=API_URL_STAGING=http://localhost:8097
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runio/core/live/presence.dart';
import 'package:runio/engine/geo.dart';
import 'package:runio/engine/track_point.dart';
import 'package:runio/state/game_controller.dart';
import 'package:runio/state/live_providers.dart';

import 'helpers.dart';

Future<void> _until(bool Function() ok, {int seconds = 10}) async {
  for (var i = 0; i < seconds * 10 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(ok(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test blocks real HTTP; this test needs the real server.
  setUpAll(() => HttpOverrides.global = null);

  test(
    'a loop run on one phone shows up on another, live',
    () async {
      final ada = (await TestPhone.signUp('Ada')).container;
      final bayo = (await TestPhone.signUp('Bayo')).container;
      addTearDown(ada.dispose);
      addTearDown(bayo.dispose);
      final adaId = ada.read(gameProvider).user!.id;

      // Bayo watches the area.
      final seen = <List<LiveRunner>>[];
      final sub = bayo.listen(liveRunnersProvider, (_, next) {
        if (next.value != null) seen.add(next.value!);
      });
      addTearDown(sub.close);
      final claims = <LiveEvent>[];
      bayo.listen(liveEventsProvider, (_, next) {
        if (next.value != null) claims.add(next.value!);
      });
      final adaPresence = ada.read(presenceProvider);
      await Future<void>.delayed(const Duration(seconds: 2)); // sockets up

      // Ada runs an 80 m ring.
      const n = 56;
      final now = DateTime.now();
      for (var i = 0; i <= n + 1; i++) {
        final p = Geo.offset(ui, 80, 2 * math.pi * i / n);
        adaPresence.publish(
          pos: TrackPoint(
            lat: p.lat,
            lng: p.lng,
            accuracy: 5,
            timestamp: now.subtract(Duration(seconds: (n + 1 - i) * 3)),
          ),
          trail: const [],
          running: true,
        );
        if (i % 20 == 0)
          await Future<void>.delayed(const Duration(milliseconds: 3100));
      }
      adaPresence.publish(
        pos: TrackPoint(
          lat: ui.lat,
          lng: ui.lng,
          accuracy: 5,
          timestamp: DateTime.now(),
        ),
        trail: const [],
        running: false,
      );

      // Ada's phone gets the server's claim; Bayo saw her run and the claim.
      await _until(
        () =>
            ada
                .read(gameProvider)
                .owners
                .values
                .where((o) => o == adaId)
                .length >
            8,
      );
      expect(seen.any((list) => list.any((r) => r.playerId == adaId)), isTrue);
      await _until(
        () => claims.whereType<RivalClaimed>().any((e) => e.playerId == adaId),
      );
      expect(bayo.read(gameProvider).playerById(adaId)?.isRival, isFalse);
    },
    skip: mailLog == null ? skipLive : false,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
