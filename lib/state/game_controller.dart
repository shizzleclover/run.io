import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/colors.dart';
import '../core/areas.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../core/regions.dart';
import '../core/storage/game_repository.dart';
import 'account.dart';
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

  /// Your profile as your account has it, after signing in. Makes your
  /// player if this phone has none yet (a new phone, or a reinstall).
  void adoptProfile({
    required String name,
    int? color,
    String? avatar,
    bool? discoverable,
  }) {
    final user = state.user;
    _commit(
      state.copyWith(
        user: user == null
            ? Player(
                id: 'me_${DateTime.now().microsecondsSinceEpoch}',
                name: name,
                color: color ?? AppColors.playerColors.first,
                avatar: avatar,
                discoverable: discoverable ?? true,
              )
            : user.copyWith(
                name: name,
                color: color,
                avatar: avatar,
                discoverable: discoverable,
              ),
      ),
    );
  }

  // ---------- server world ----------

  /// Signing in hands the world to the server. Your player takes your
  /// account's id; the phone's ghosts and land go, and the server's arrive.
  /// Runs stay.
  void enterServerWorld(String userId) {
    final user = state.user;
    if (user == null || user.id == userId) return;
    _commit(
      state.copyWith(
        user: Player(
          id: userId,
          name: user.name,
          color: user.color,
          avatar: user.avatar,
          discoverable: user.discoverable,
          crewId: user.crewId,
        ),
        rivals: const [],
        owners: const {},
        touched: const {},
        following: const {},
        nearbyAlerted: const {},
        crews: [
          for (final c in state.crews)
            if (!c.ghost) c,
        ],
      ),
    );
  }

  /// Ownership for [regionIds] as the server has it. Cells of those
  /// regions not in [cells] are neutral. [stale] are your faded cells.
  void applyServerTerritory({
    required Set<String> regionIds,
    required Map<String, String> cells,
    required Set<String> stale,
    required List<Player> players,
    List<Crew> crews = const [],
  }) {
    const regions = RegionGrid();
    final owners = {
      for (final e in state.owners.entries)
        if (!regionIds.contains(regions.regionOf(e.key, _grid))) e.key: e.value,
      ...cells,
    };
    final me = state.user?.id;
    final today = epochDay(DateTime.now());
    final touched = {
      for (final e in cells.entries)
        if (e.value == me)
          // Faded on the server: draw it faded here too.
          e.key: stale.contains(e.key) ? today - kDecay.staleAfterDays : today,
    };
    _commit(
      _withPlayers(players, crews).copyWith(
        owners: owners,
        touched: {
          for (final e in state.touched.entries)
            if (owners[e.key] == me &&
                !regionIds.contains(regions.regionOf(e.key, _grid)))
              e.key: e.value,
          ...touched,
        },
      ),
    );
  }

  /// Live: [cells] now belong to [ownerId].
  void applyServerClaim(
    String ownerId,
    List<String> cells, {
    Player? owner,
    Crew? crew,
  }) {
    final base = owner == null ? state : _withPlayers([owner], [?crew]);
    final today = epochDay(DateTime.now());
    final mine = ownerId == state.user?.id;
    _commit(
      base.copyWith(
        owners: {...state.owners, for (final c in cells) c: ownerId},
        touched: {
          for (final e in state.touched.entries)
            if (!cells.contains(e.key) || mine) e.key: e.value,
          if (mine)
            for (final c in cells) c: today,
        },
      ),
    );
  }

  /// Live: [cells] went neutral (a cut, decay, a ghost going home).
  void applyServerLoss(List<String> cells) {
    final gone = cells.toSet();
    _commit(
      state.copyWith(
        owners: {
          for (final e in state.owners.entries)
            if (!gone.contains(e.key)) e.key: e.value,
        },
        touched: {
          for (final e in state.touched.entries)
            if (!gone.contains(e.key)) e.key: e.value,
        },
      ),
    );
  }

  /// Adds or refreshes other players (from the server), and the crews
  /// they run with.
  void upsertPlayers(List<Player> players, {List<Crew> crews = const []}) {
    if (players.isEmpty) return;
    _commit(_withPlayers(players, crews));
  }

  GameData _withPlayers(List<Player> players, [List<Crew> crews = const []]) {
    final me = state.user?.id;
    final byId = {for (final r in state.rivals) r.id: r};
    for (final p in players) {
      if (p.id != me) byId[p.id] = p;
    }
    // Your own crew's name is yours to keep in step; others come from cards.
    final mine = state.user?.crewId;
    final byCode = {for (final c in state.crews) c.code: c};
    for (final c in crews) {
      if (c.code != mine) byCode[c.code] = c;
    }
    return state.copyWith(
      rivals: byId.values.toList(),
      crews: byCode.values.toList(),
    );
  }

  void setFollowing(Set<String> ids) => _commit(state.copyWith(following: ids));

  /// Runs from your account that this phone doesn't have yet.
  void mergeRuns(List<RunRecord> runs) {
    final known = {for (final r in state.runs) r.id};
    final fresh = [
      for (final r in runs)
        if (!known.contains(r.id)) r,
    ];
    if (fresh.isEmpty) return;
    _commit(
      state.copyWith(
        runs: [...state.runs, ...fresh]
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
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

    // Signed in: the server seeds ghosts, grows them and decays land.
    if (ref.read(serverModeProvider)) {
      if (state.home == null) _commit(state.copyWith(home: here));
      return null;
    }

    if (state.rivals.isEmpty) {
      _seed(here, user);
      return null;
    }
    // Saves from before crews existed: put the ghosts in their crews.
    if (!state.crews.any((c) => c.ghost)) _formGhostCrews();
    if (state.lastExpansionDay == _today()) return null;
    _retreatGhosts(here);

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
      rivalIds: [for (final r in state.activeRivals) r.id],
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
    _formGhostCrews();
  }

  /// Ghosts run in two crews, so the crew board has someone to beat
  /// before real crews sign up.
  void _formGhostCrews() {
    final places = [
      ...?stateByCode(state.homeState)?.places,
      ...kNationalPlaces,
    ];
    final suffixes = ['Pacers', 'Striders'];
    final crews = [
      for (var i = 0; i < suffixes.length; i++)
        Crew(
          code: 'GHOST-$i',
          name: '${places[i % places.length]} ${suffixes[i]}',
          ghost: true,
        ),
    ];
    _commit(
      state.copyWith(
        crews: [
          for (final c in state.crews)
            if (!c.ghost) c,
          ...crews,
        ],
        rivals: [
          for (var i = 0; i < state.rivals.length; i++)
            state.rivals[i].copyWith(
              crewId: () => crews[i % crews.length].code,
            ),
        ],
      ),
    );
  }

  /// Ghosts make way for real runners. With none around they all play;
  /// each real runner in your area sends a share of them home, smallest
  /// first, and their land goes neutral for real people to claim.
  void _retreatGhosts(LatLng here) {
    final center = areaAt(here)?.center ?? here;
    final radius = areaAt(here)?.radiusM ?? kNearbyAreaRadiusM;
    final real = <String>{};
    final ghostCells = <String, int>{};
    final ghostIds = {for (final r in state.activeRivals) r.id};
    state.owners.forEach((cell, owner) {
      if (Geo.haversine(_grid.center(cell), center) > radius) return;
      if (ghostIds.contains(owner)) {
        ghostCells[owner] = (ghostCells[owner] ?? 0) + 1;
      } else {
        real.add(owner);
      }
    });
    if (state.user != null) real.add(state.user!.id);

    final keep = (kRivalCount * (1 - real.length / kGhostRetreatRunners))
        .ceil()
        .clamp(0, kRivalCount);
    final active = state.activeRivals
      ..sort(
        (a, b) => (ghostCells[b.id] ?? 0).compareTo(ghostCells[a.id] ?? 0),
      );
    if (active.length <= keep) return;
    final leaving = {for (final r in active.skip(keep)) r.id};
    _commit(
      state.copyWith(
        rivals: [
          for (final r in state.rivals)
            leaving.contains(r.id) ? r.copyWith(retired: true) : r,
        ],
        owners: Map.of(state.owners)
          ..removeWhere((_, owner) => leaving.contains(owner)),
      ),
    );
  }

  // ---------- crews ----------

  static const _codeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Start a crew and join it. Returns its invite code.
  String createCrew(String name) {
    final rng = math.Random.secure();
    String part() => [
      for (var i = 0; i < 4; i++) _codeChars[rng.nextInt(_codeChars.length)],
    ].join();
    final code = '${part()}-${part()}';
    joinCrew(code: code, name: name);
    return code;
  }

  /// Join the crew with [code]. Leaves your current crew.
  void joinCrew({required String code, required String name}) {
    final user = state.user;
    final clean = name.trim();
    if (user == null) return;
    final crew = Crew(code: code, name: clean.isEmpty ? 'Crew $code' : clean);
    _commit(
      state.copyWith(
        user: user.copyWith(crewId: () => code),
        crews: [
          for (final c in state.crews)
            if (c.ghost) c,
          crew,
        ],
      ),
    );
  }

  void renameCrew(String name) {
    final crew = state.myCrew;
    final clean = name.trim();
    if (crew == null || clean.isEmpty) return;
    _commit(
      state.copyWith(
        crews: [
          for (final c in state.crews)
            c.code == crew.code ? Crew(code: c.code, name: clean) : c,
        ],
      ),
    );
  }

  void leaveCrew() {
    final user = state.user;
    if (user == null) return;
    _commit(
      state.copyWith(
        user: user.copyWith(crewId: () => null),
        crews: [
          for (final c in state.crews)
            if (c.ghost) c,
        ],
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
      crews: [
        for (final c in state.crews)
          if (!c.ghost) c,
      ],
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
