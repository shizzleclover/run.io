import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/colors.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../core/regions.dart';
import '../core/storage/game_repository.dart';
import '../core/avatars.dart';
import '../engine/claim_engine.dart';
import '../engine/cut_rules.dart';
import '../engine/decay.dart';
import '../engine/engine_config.dart';
import '../engine/geo.dart';
import '../engine/hex_grid.dart';
import '../engine/name_gen.dart';
import '../engine/rival_seeder.dart';
import '../engine/territory_index.dart';

/// Overridden in main.dart once the repository has been opened.
final repositoryProvider = Provider<GameRepository>(
  (ref) => throw UnimplementedError('repositoryProvider not overridden'),
);

/// Overridden in main.dart with the data loaded from disk.
final initialDataProvider = Provider<GameData>(
  (ref) => throw UnimplementedError('initialDataProvider not overridden'),
);

final gridProvider = Provider<HexGrid>((ref) => const HexGrid());

final gameProvider = NotifierProvider<GameController, GameData>(
  GameController.new,
);

/// The state you play in, if known.
final homeStateProvider = Provider<NgState?>(
  (ref) => stateByCode(ref.watch(gameProvider.select((g) => g.homeState))),
);

/// Best guess at where you are before a GPS fix: your home, else your
/// state's capital, else null.
final fallbackCenterProvider = Provider<LatLng?>(
  (ref) =>
      ref.watch(gameProvider.select((g) => g.home)) ??
      ref.watch(homeStateProvider)?.center,
);

/// Real-world area of one hex around the player's home.
final cellAreaProvider = Provider<double>((ref) {
  final center = ref.watch(fallbackCenterProvider) ?? kDefaultCenter;
  return ref.watch(gridProvider).cellAreaM2(center.lat);
});

class LeaderEntry {
  const LeaderEntry(this.player, this.cells, this.areaM2);
  final Player player;
  final int cells;
  final double areaM2;
}

/// Ownership indexed by player and region. Rebuilt only when ownership
/// changes, so screens don't each rescan every hex.
final territoryIndexProvider = Provider<TerritoryIndex>(
  (ref) => TerritoryIndex.build(
    ref.watch(gameProvider.select((g) => g.owners)),
    grid: ref.watch(gridProvider),
  ),
);

final leaderboardProvider = Provider<List<LeaderEntry>>((ref) {
  final players = ref.watch(gameProvider.select((g) => g.players));
  final index = ref.watch(territoryIndexProvider);
  final cellArea = ref.watch(cellAreaProvider);
  return [
    for (final p in players)
      LeaderEntry(p, index.countOf(p.id), index.countOf(p.id) * cellArea),
  ]..sort((a, b) => b.cells.compareTo(a.cells));
});

/// Time left before you can run again after being cut, or null.
final cooldownProvider = StreamProvider<Duration?>((ref) async* {
  final until = ref.watch(gameProvider.select((g) => g.cooldownUntil));
  while (true) {
    final left = until?.difference(DateTime.now());
    if (left == null || left.isNegative) {
      yield null;
      return;
    }
    yield left;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
});

/// What happened to your land since the last daily update.
class AwayReport {
  const AwayReport({required this.takenByRivals, required this.decayed});
  final int takenByRivals;
  final int decayed;
  bool get isEmpty => takenByRivals == 0 && decayed == 0;
}

const kDecay = DecayRule();

/// Your cells that have gone stale. Drawn faded on the map.
final staleCellsProvider = Provider<Set<String>>((ref) {
  final me = ref.watch(gameProvider.select((g) => g.user?.id));
  final owners = ref.watch(gameProvider.select((g) => g.owners));
  final touched = ref.watch(gameProvider.select((g) => g.touched));
  if (me == null) return const {};
  return kDecay.stale(
    owners: owners,
    touched: touched,
    playerId: me,
    today: epochDay(DateTime.now()),
  );
});

class GameController extends Notifier<GameData> {
  @override
  GameData build() => ref.read(initialDataProvider);

  GameRepository get _repo => ref.read(repositoryProvider);
  HexGrid get _grid => ref.read(gridProvider);

  Timer? _saveTimer;

  /// Updates are instant; disk writes are batched. A run can change
  /// ownership every second, and rewriting the whole file each time gets
  /// slow as territory grows. Call [flush] when it must be on disk now.
  void _commit(GameData data) {
    state = data;
    _saveTimer ??= Timer(const Duration(seconds: 2), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _repo.save(state);
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  // ---------- user ----------

  void createUser({required String name, required int color, String? avatar}) {
    final clean = name.trim();
    _commit(
      state.copyWith(
        user: Player(
          id: 'me_${DateTime.now().microsecondsSinceEpoch}',
          name: clean.isEmpty ? NameGen(null, kNationalPlaces).next() : clean,
          color: color,
          avatar: avatar,
        ),
      ),
    );
  }

  void completePermissions() {
    if (!state.permissionsDone) _commit(state.copyWith(permissionsDone: true));
  }

  void rename(String name) {
    final user = state.user;
    final clean = name.trim();
    if (user == null || clean.isEmpty) return;
    _commit(state.copyWith(user: user.copyWith(name: clean)));
  }

  /// If a rival already has the colour, they get your old one.
  void recolor(int color) {
    final user = state.user;
    if (user == null || user.color == color) return;
    final rivals = [
      for (final r in state.rivals)
        r.color == color ? r.copyWith(color: user.color) : r,
    ];
    _commit(
      state.copyWith(
        user: user.copyWith(color: color),
        rivals: rivals,
      ),
    );
  }

  /// [avatar] is 'p:<n>' or 'f:<file>'. See avatars.dart.
  void setAvatar(String avatar) {
    final user = state.user;
    if (user == null) return;
    _commit(state.copyWith(user: user.copyWith(avatar: avatar)));
  }

  /// Anonymous: others see "Anonymous runner", no stats, no nearby alerts.
  void setDiscoverable(bool value) {
    final user = state.user;
    if (user == null) return;
    _commit(state.copyWith(user: user.copyWith(discoverable: value)));
  }

  void markNearbyAlerted(String playerId) => _commit(
    state.copyWith(
      nearbyAlerted: {
        ...state.nearbyAlerted,
        playerId: epochDay(DateTime.now()),
      },
    ),
  );

  void toggleFollow(String playerId) {
    final next = {...state.following};
    if (!next.remove(playerId)) next.add(playerId);
    _commit(state.copyWith(following: next));
  }

  void updateSettings(AppSettings Function(AppSettings s) change) =>
      _commit(state.copyWith(settings: change(state.settings)));

  /// Switch state. Rivals get local names; their territory stays put,
  /// since it's seeded around wherever you actually are.
  void setHomeState(String code) {
    final st = stateByCode(code);
    if (st == null || state.homeState == code) return;
    final names = NameGen(null, st.places);
    final used = {if (state.user != null) state.user!.name};
    final rivals = <Player>[];
    for (final r in state.rivals) {
      final name = names.next(exclude: used);
      used.add(name);
      rivals.add(r.copyWith(name: name));
    }
    _commit(state.copyWith(homeState: code, rivals: rivals));
  }

  // ---------- world ----------

  /// Called on the first GPS fix. Seeds rivals around you the first time,
  /// and once per day after that: your forgotten land decays and rivals
  /// grow, mostly toward you. Returns what you lost, if anything.
  AwayReport? ensureWorld(LatLng here) {
    final user = state.user;
    if (user == null) return null;

    // First fix: guess your state so rival names and the map fit it.
    if (state.homeState == null) {
      final guess = nearestState(here);
      if (guess != null) _commit(state.copyWith(homeState: guess.code));
    }

    if (state.rivals.isEmpty) {
      _seed(here, user);
      return null;
    }
    if (state.lastExpansionDay == _today()) return null;

    final today = epochDay(DateTime.now());
    final me = user.id;
    // Saves from before decay existed have no dates. Start them fresh.
    final touched = {
      for (final e in state.owners.entries)
        if (e.value == me) e.key: state.touched[e.key] ?? today,
    };
    final mineBefore = touched.length;

    var owners = kDecay.expire(
      owners: state.owners,
      touched: touched,
      playerId: me,
      today: today,
    );
    final decayed = mineBefore - owners.values.where((o) => o == me).length;

    final mine = {
      for (final e in owners.entries)
        if (e.value == me) e.key,
    };
    // Rivals you raided in the last three days come back harder.
    final since = DateTime.now().subtract(const Duration(days: 3));
    final angry = {
      for (final r in state.runs)
        if (r.startedAt.isAfter(since)) ...r.stolenFrom.keys,
    };
    owners = RivalSeeder(_grid).expand(
      owners: owners,
      rivalIds: [for (final r in state.rivals) r.id],
      rng: math.Random(),
      targets: mine,
      weak: kDecay.stale(
        owners: owners,
        touched: touched,
        playerId: me,
        today: today,
      ),
      angry: angry,
    );
    final mineAfter = owners.values.where((o) => o == me).length;
    touched.removeWhere((cell, _) => owners[cell] != me);

    _commit(
      state.copyWith(
        owners: owners,
        touched: touched,
        lastExpansionDay: _today(),
      ),
    );
    return AwayReport(
      takenByRivals: mineBefore - decayed - mineAfter,
      decayed: decayed,
    );
  }

  void _seed(LatLng here, Player user) {
    final rng = math.Random();
    final colors = AppColors.playerColors.where((c) => c != user.color).toList()
      ..shuffle(rng);
    final names = NameGen(
      rng,
      stateByCode(state.homeState)?.places ?? kNationalPlaces,
    );
    final used = {user.name};
    final rivals = <Player>[];
    for (var i = 0; i < kRivalCount; i++) {
      final name = names.next(exclude: used);
      used.add(name);
      rivals.add(
        Player(
          id: 'rival_$i',
          name: name,
          color: colors[i % colors.length],
          isRival: true,
          avatar: presetAvatarId(rng.nextInt(kAvatarPresets.length)),
          // A few runners keep to themselves, like real people will.
          discoverable: rng.nextDouble() > 0.25,
        ),
      );
    }

    final owners = RivalSeeder(_grid).seed(
      center: here,
      rivalIds: [for (final r in rivals) r.id],
      rng: rng,
    )..addAll(state.owners); // your existing claims win

    _commit(
      state.copyWith(
        rivals: rivals,
        owners: owners,
        home: here,
        lastExpansionDay: _today(),
      ),
    );
  }

  void reseedRivals(LatLng here) {
    final user = state.user;
    if (user == null) return;
    final rivalIds = {for (final r in state.rivals) r.id};
    final owners = Map<String, String>.of(state.owners)
      ..removeWhere((_, owner) => rivalIds.contains(owner));
    state = GameData(
      user: state.user,
      rivals: const [],
      owners: owners,
      runs: state.runs,
      settings: state.settings,
      home: here,
      homeState: state.homeState,
      touched: state.touched,
      permissionsDone: state.permissionsDone,
      // Rival ids are reused on reseed, but they're new people now.
      following: const {},
    );
    _seed(here, user);
  }

  // ---------- runs ----------

  void applyClaim(ClaimResult result) {
    final today = epochDay(DateTime.now());
    _commit(
      state.copyWith(
        owners: result.owners,
        touched: {...state.touched, for (final c in result.cells) c: today},
      ),
    );
  }

  /// A live rival closed a loop. Their land, your loss.
  void applyRivalClaim(ClaimResult result) {
    final me = state.user?.id;
    _commit(
      state.copyWith(
        owners: result.owners,
        touched: {
          for (final e in state.touched.entries)
            if (result.owners[e.key] == me) e.key: e.value,
        },
      ),
    );
  }

  /// Running through your own land keeps it fresh.
  void touch(Set<String> cells) {
    final me = state.user?.id;
    final today = epochDay(DateTime.now());
    final fresh = {
      for (final c in cells)
        if (state.owners[c] == me && state.touched[c] != today) c: today,
    };
    if (fresh.isEmpty) return;
    _commit(state.copyWith(touched: {...state.touched, ...fresh}));
  }

  void addRun(RunRecord run) =>
      _commit(state.copyWith(runs: [run, ...state.runs]));

  void removeRun(String id) => _commit(
    state.copyWith(
      runs: [
        for (final r in state.runs)
          if (r.id != id) r,
      ],
    ),
  );

  Future<void> wipe() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    state = GameData.empty();
    await _repo.wipe();
  }

  // ---------- cuts ----------

  /// Hardcore: you were cut. Every cell you own goes neutral and you sit
  /// out the cooldown.
  void youWereCut() {
    final me = state.user?.id;
    if (me == null) return;
    _commit(
      state.copyWith(
        owners: const CutRules().wipe(state.owners, me),
        touched: const {},
        deaths: state.deaths + 1,
        cooldownUntil: DateTime.now().add(EngineConfig.cutCooldown),
      ),
    );
    flush();
  }

  /// You cut a rival. Same rule for them: all their land goes neutral.
  void youCut(String rivalId) {
    _commit(
      state.copyWith(
        owners: const CutRules().wipe(state.owners, rivalId),
        kills: state.kills + 1,
      ),
    );
  }

  /// A cut rival comes back with a small patch of land near [center].
  void respawnRival(String rivalId, LatLng center) {
    final owners = RivalSeeder(_grid).seed(
      center: center,
      rivalIds: [rivalId],
      rng: math.Random(),
    )..addAll(state.owners); // never on top of anyone
    _commit(state.copyWith(owners: owners));
  }
}
