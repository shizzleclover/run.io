import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/cards.dart';
import '../core/api/session.dart';
import '../core/avatars.dart';
import '../core/models.dart';
import '../engine/geo.dart';
import 'account.dart';
import 'game_controller.dart';

final cloudSyncProvider = Provider<CloudSync>(CloudSync.new);

/// Your crew as the server has it, with real crewmates. Null when signed
/// out or not in a crew.
final remoteCrewProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  if (ref.watch(accountProvider) == null) return null;
  ref.watch(gameProvider.select((g) => g.user?.crewId));
  return await ref.read(apiProvider)!.get('/crews/mine')
      as Map<String, dynamic>?;
});

/// Keeps this phone and the account in step: profile, run history and crew.
///
/// The phone stays the source for anything played offline: runs upload
/// when there's signal, and a new phone pulls everything back down.
class CloudSync {
  CloudSync(this.ref);

  final Ref ref;

  ApiClient? get _api => ref.read(apiProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);
  GameController get _game => ref.read(gameProvider.notifier);
  bool get _signedIn => _api != null && _store.current != null;

  bool _pushingRuns = false;
  Timer? _profileTimer;

  /// Right after signing in. A brand-new account takes this phone's
  /// profile; an existing one wins over whatever is on the phone.
  Future<void> afterSignIn(Map<String, dynamic> me) async {
    final game = ref.read(gameProvider);
    final username = me['username'] as String;
    final fresh = me['color'] == null;
    if (fresh && game.user != null) {
      _game.rename(username);
      await _guard(pushProfile);
    } else {
      _game.adoptProfile(
        name: username,
        color: me['color'] == null ? null : fromRgb(me['color'] as int),
        avatar: me['avatar'] as String?,
        discoverable: me['discoverable'] as bool?,
      );
      final st = me['homeState'] as String?;
      if (st != null) _game.setHomeState(st);
    }
    // From here the server owns the world: land, ghosts, live play.
    _game.enterServerWorld(me['id'] as String);
    await _guard(syncCrew);
    await _guard(syncFollowing);
    await _guard(fresh ? pushGoals : pullGoals);
    await _guard(pullRuns);
    await _guard(pushRuns);
    await _game.flush();
  }

  /// On launch: catch up anything a previous version of the app didn't do.
  Future<void> onLaunch() async {
    final session = _store.current;
    if (!_signedIn || session == null) return;
    _game.enterServerWorld(session.userId);
    await _guard(syncFollowing);
    await _guard(pushRuns);
  }

  /// Who you follow, with their cards so Home can show them.
  Future<void> syncFollowing() async {
    if (!_signedIn) return;
    final res =
        await _api!.get('/me/following', query: {'limit': '100'})
            as Map<String, dynamic>;
    final cards = (res['items'] as List).cast<Map<String, dynamic>>();
    _game.upsertPlayers(
      [for (final c in cards) playerFromCard(c)],
      crews: [for (final c in cards) ?crewFromCard(c)],
    );
    _game.setFollowing({for (final c in cards) c['id'] as String});
  }

  /// Weekly goals live in the account, so a new phone gets them back.
  Future<void> pullGoals() async {
    final api = ref.read(runioApiProvider);
    if (!_signedIn || api == null) return;
    final g = await api.goals();
    _game.updateSettings(
      (s) => s.copyWith(
        weeklyDistanceGoalM: (g['goalDistanceM'] as num).toDouble(),
        weeklyRunsGoal: g['goalRuns'] as int,
      ),
    );
  }

  Future<void> pushGoals() async {
    final api = ref.read(runioApiProvider);
    if (!_signedIn || api == null) return;
    final s = ref.read(gameProvider).settings;
    await api.setGoals(
      distanceM: s.weeklyDistanceGoalM.round().clamp(1000, 500000),
      runs: s.weeklyRunsGoal.clamp(1, 14),
    );
  }

  void goalsChanged() {
    if (_signedIn) _guard(pushGoals);
  }

  /// Deletes a run here and in the account. Its land stays either way.
  Future<void> deleteRun(String runId) async {
    _game.removeRun(runId);
    final api = ref.read(runioApiProvider);
    if (!_signedIn || api == null) return;
    await _guard(() async {
      final serverId = await api.runIdFor(runId);
      if (serverId != null) await api.deleteRun(serverId);
    });
  }

  /// Follow or unfollow: shown at once, undone if the server says no.
  Future<void> toggleFollow(String playerId) async {
    final following = ref.read(gameProvider).following.contains(playerId);
    _game.toggleFollow(playerId);
    if (!_signedIn) return;
    try {
      if (following) {
        await _api!.delete('/players/$playerId/follow');
      } else {
        await _api!.post('/players/$playerId/follow');
      }
    } on ApiException catch (e) {
      _game.toggleFollow(playerId);
      debugPrint('follow: $e');
    }
  }

  /// Profile changes, sent a moment after the last one.
  void profileChanged() {
    if (!_signedIn) return;
    _profileTimer?.cancel();
    _profileTimer = Timer(
      const Duration(seconds: 2),
      () => _guard(pushProfile),
    );
  }

  Future<void> pushProfile() async {
    final game = ref.read(gameProvider);
    final user = game.user;
    if (!_signedIn || user == null) return;
    await _api!.patch('/me', {
      'color': user.color & 0xFFFFFF,
      'discoverable': user.discoverable,
      'homeState': ?game.homeState,
      if (user.avatar?.startsWith('p:') ?? false) 'avatar': user.avatar,
    });
    final avatar = user.avatar;
    if (avatar != null &&
        avatar.startsWith('f:') &&
        avatar != _uploadedAvatar) {
      await _uploadPhoto(avatar);
    }
  }

  /// The last photo sent up, so other profile edits don't resend it.
  String? _uploadedAvatar;

  /// Photo avatars go straight to storage with a signed URL, then the
  /// server is told to use it. Others see it as a link.
  Future<void> _uploadPhoto(String avatar) async {
    final file = AvatarStore.file(avatar.substring(2));
    if (file == null || !await file.exists()) return;
    try {
      final slot =
          await _api!.post('/me/avatar/upload-url', {
                'contentType': 'image/jpeg',
              })
              as Map<String, dynamic>;
      final http = HttpClient();
      try {
        final req = await http.putUrl(Uri.parse(slot['uploadUrl'] as String));
        req.headers.contentType = ContentType('image', 'jpeg');
        req.add(await file.readAsBytes());
        final res = await req.close();
        await res.drain<void>();
        if (res.statusCode >= 300)
          throw HttpException('upload ${res.statusCode}');
      } finally {
        http.close();
      }
      await _api!.put('/me/avatar', {'key': slot['key']});
      _uploadedAvatar = avatar;
    } on ApiException catch (e) {
      // 503 uploads_off: storage isn't set up on this server yet.
      debugPrint('avatar upload: $e');
    }
  }

  /// Uploads every run this account doesn't have yet. Safe to call often.
  Future<void> pushRuns() async {
    if (!_signedIn || _pushingRuns) return;
    _pushingRuns = true;
    try {
      var synced = {..._store.current!.syncedRuns};
      final pending = [
        for (final r in ref.read(gameProvider).runs)
          if (!synced.contains(r.id)) r,
      ];
      for (final run in pending.reversed) {
        try {
          await _api!.post('/runs', runJson(run));
        } on ApiException catch (e) {
          if (e.code == 'offline' || e.status >= 500 || e.status == 401) break;
          // Rejected (e.g. implausible): don't retry it forever.
        }
        synced = {...synced, run.id};
      }
      final session = _store.current;
      if (session != null) {
        await _store.save(session.copyWith(syncedRuns: synced));
      }
    } finally {
      _pushingRuns = false;
    }
  }

  /// Runs from the account this phone doesn't have (new phone, reinstall).
  Future<void> pullRuns() async {
    if (!_signedIn) return;
    final restored = <RunRecord>[];
    String? before;
    for (var page = 0; page < 20; page++) {
      final res =
          await _api!.get(
                '/runs',
                query: {'full': 'true', 'limit': '50', 'before': ?before},
              )
              as Map<String, dynamic>;
      for (final r in res['items'] as List) {
        restored.add(runFromJson(r as Map<String, dynamic>));
      }
      before = res['nextBefore'] as String?;
      if (before == null) break;
    }
    _game.mergeRuns(restored);
    final session = _store.current;
    if (session != null) {
      await _store.save(
        session.copyWith(
          syncedRuns: {...session.syncedRuns, for (final r in restored) r.id},
        ),
      );
    }
  }

  /// One crew per runner, held by the server. A crew made on this phone
  /// before accounts is carried over under its code.
  Future<void> syncCrew() async {
    if (!_signedIn) return;
    final remote = await _api!.get('/crews/mine') as Map<String, dynamic>?;
    if (remote != null) {
      _game.joinCrew(
        code: remote['code'] as String,
        name: remote['name'] as String,
      );
      return;
    }
    final local = ref.read(gameProvider).myCrew;
    if (local == null) return;
    final joined =
        await _api!.post('/crews/join', {
              'code': local.code,
              'name': local.name,
              'fromLocal': true,
            })
            as Map<String, dynamic>;
    _game.joinCrew(
      code: joined['code'] as String,
      name: joined['name'] as String,
    );
  }

  // ---- Crew actions: on the server first when signed in, then here ----

  Future<void> createCrew(String name) async {
    if (!_signedIn) {
      _game.createCrew(name);
      return;
    }
    final crew =
        await _api!.post('/crews', {'name': name}) as Map<String, dynamic>;
    _game.joinCrew(code: crew['code'] as String, name: crew['name'] as String);
    ref.invalidate(remoteCrewProvider);
  }

  Future<void> joinCrew({required String code, String? name}) async {
    if (!_signedIn) {
      _game.joinCrew(code: code, name: name ?? '');
      return;
    }
    final crew =
        await _api!.post('/crews/join', {'code': code}) as Map<String, dynamic>;
    _game.joinCrew(code: crew['code'] as String, name: crew['name'] as String);
    ref.invalidate(remoteCrewProvider);
  }

  Future<void> renameCrew(String name) async {
    if (_signedIn) await _api!.patch('/crews/mine', {'name': name});
    _game.renameCrew(name);
    ref.invalidate(remoteCrewProvider);
  }

  Future<void> leaveCrew() async {
    if (_signedIn) await _api!.post('/crews/mine/leave');
    _game.leaveCrew();
    ref.invalidate(remoteCrewProvider);
  }

  /// Sync is best effort: a failure here must never block playing.
  Future<void> _guard(Future<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      debugPrint('sync: $e');
    }
  }
}

/// Server colours are 0xRRGGBB; the app's are ARGB.
int fromRgb(int rgb) => 0xFF000000 | rgb;

Map<String, dynamic> runJson(RunRecord r) => {
  'clientId': r.id,
  'startedAt': r.startedAt.toUtc().toIso8601String(),
  'endedAt': r.endedAt.toUtc().toIso8601String(),
  'distanceM': r.distanceM,
  'movingS': r.movingSeconds,
  'splits': r.splits,
  'path': [for (final p in r.path) p.toJson()],
  'cellsClaimed': r.cells.length,
};

RunRecord runFromJson(Map<String, dynamic> j) => RunRecord(
  id: j['clientId'] as String,
  startedAt: DateTime.parse(j['startedAt'] as String).toLocal(),
  endedAt: DateTime.parse(j['endedAt'] as String).toLocal(),
  distanceM: (j['distanceM'] as num).toDouble(),
  movingSeconds: j['movingS'] as int,
  path: [for (final p in j['path'] as List) LatLng.fromJson(p as List)],
  // Which hexes a run took is kept on the phone that ran it.
  cells: const [],
  stolenFrom: const {},
  splits: List<int>.from(j['splits'] as List? ?? const []),
);
