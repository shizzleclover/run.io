import '../app/theme/colors.dart';
import '../engine/geo.dart';

/// Avatar id for anyone who chose to be anonymous.
const kAnonymousAvatar = 'anon';

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.color,
    this.isRival = false,
    this.avatar,
    this.discoverable = true,
  });

  final String id;
  final String name;

  /// 'p:3' for built-in avatar 3, 'f:me.jpg' for a photo in the avatars
  /// folder, null for a built-in avatar picked from the id.
  final String? avatar;

  /// False: shown to others as an anonymous runner, no stats, no nearby
  /// alerts. Their territory still counts and shows, just without a name.
  final bool discoverable;

  /// What other people see. Your own name and avatar are always yours.
  String get shownName => discoverable ? name : 'Anonymous runner';
  String? get shownAvatar => discoverable ? avatar : kAnonymousAvatar;

  /// ARGB int, e.g. 0xFF3DFF8A.
  final int color;
  final bool isRival;

  Player copyWith({
    String? name,
    int? color,
    String? avatar,
    bool? discoverable,
  }) => Player(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    isRival: isRival,
    avatar: avatar ?? this.avatar,
    discoverable: discoverable ?? this.discoverable,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'isRival': isRival,
    'avatar': avatar,
    'discoverable': discoverable,
  };

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    id: j['id'] as String,
    name: j['name'] as String,
    color: AppColors.migrateColor(j['color'] as int),
    isRival: j['isRival'] as bool? ?? false,
    avatar: j['avatar'] as String?,
    discoverable: j['discoverable'] as bool? ?? true,
  );
}

class RunRecord {
  const RunRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceM,
    required this.movingSeconds,
    required this.path,
    required this.cells,
    required this.stolenFrom,
    this.recovered = false,
    this.splits = const [],
    this.cutBy,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceM;
  final int movingSeconds;
  final List<LatLng> path;

  /// Cells this run claimed.
  final List<String> cells;
  final Map<String, int> stolenFrom;

  /// True if this run was rescued after the app was killed mid-run.
  final bool recovered;

  /// Moving seconds for each full km (or mile, if that was the unit).
  final List<int> splits;

  /// Set if someone cut your trail and ended this run (and your land).
  final String? cutBy;

  int get stolenTotal => stolenFrom.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'distanceM': distanceM,
    'movingSeconds': movingSeconds,
    'path': [for (final p in path) p.toJson()],
    'cells': cells,
    'stolenFrom': stolenFrom,
    'recovered': recovered,
    'splits': splits,
    'cutBy': cutBy,
  };

  factory RunRecord.fromJson(Map<String, dynamic> j) => RunRecord(
    id: j['id'] as String,
    startedAt: DateTime.parse(j['startedAt'] as String),
    endedAt: DateTime.parse(j['endedAt'] as String),
    distanceM: (j['distanceM'] as num).toDouble(),
    movingSeconds: j['movingSeconds'] as int,
    path: [for (final p in j['path'] as List) LatLng.fromJson(p as List)],
    cells: List<String>.from(j['cells'] as List),
    stolenFrom: Map<String, int>.from(j['stolenFrom'] as Map),
    recovered: j['recovered'] as bool? ?? false,
    splits: List<int>.from(j['splits'] as List? ?? const []),
    cutBy: j['cutBy'] as String?,
  );
}

class AppSettings {
  const AppSettings({
    this.useMiles = false,
    this.haptics = true,
    this.keepScreenOn = true,
    this.simMode = false,
    this.debugUnlocked = false,
    this.themeMode = 'dark',
    this.autoPause = true,
    this.weeklyDistanceGoalM = 10000,
    this.weeklyRunsGoal = 3,
    this.nearbyAlerts = true,
  });

  final bool useMiles;
  final bool haptics;
  final bool keepScreenOn;
  final bool simMode;
  final bool debugUnlocked;

  /// 'dark', 'light' or 'system'.
  final String themeMode;

  /// Stop the clock when you stand still. The loop stays open.
  final bool autoPause;
  final double weeklyDistanceGoalM;
  final int weeklyRunsGoal;

  /// "A potential friend is nearby" notifications. Only ever sent while
  /// you're discoverable yourself.
  final bool nearbyAlerts;

  AppSettings copyWith({
    bool? useMiles,
    bool? haptics,
    bool? keepScreenOn,
    bool? simMode,
    bool? debugUnlocked,
    String? themeMode,
    bool? autoPause,
    double? weeklyDistanceGoalM,
    int? weeklyRunsGoal,
    bool? nearbyAlerts,
  }) => AppSettings(
    useMiles: useMiles ?? this.useMiles,
    haptics: haptics ?? this.haptics,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    simMode: simMode ?? this.simMode,
    debugUnlocked: debugUnlocked ?? this.debugUnlocked,
    themeMode: themeMode ?? this.themeMode,
    autoPause: autoPause ?? this.autoPause,
    weeklyDistanceGoalM: weeklyDistanceGoalM ?? this.weeklyDistanceGoalM,
    weeklyRunsGoal: weeklyRunsGoal ?? this.weeklyRunsGoal,
    nearbyAlerts: nearbyAlerts ?? this.nearbyAlerts,
  );

  Map<String, dynamic> toJson() => {
    'useMiles': useMiles,
    'haptics': haptics,
    'keepScreenOn': keepScreenOn,
    'simMode': simMode,
    'debugUnlocked': debugUnlocked,
    'themeMode': themeMode,
    'autoPause': autoPause,
    'weeklyDistanceGoalM': weeklyDistanceGoalM,
    'weeklyRunsGoal': weeklyRunsGoal,
    'nearbyAlerts': nearbyAlerts,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    useMiles: j['useMiles'] as bool? ?? false,
    haptics: j['haptics'] as bool? ?? true,
    keepScreenOn: j['keepScreenOn'] as bool? ?? true,
    simMode: j['simMode'] as bool? ?? false,
    debugUnlocked: j['debugUnlocked'] as bool? ?? false,
    themeMode: j['themeMode'] as String? ?? 'dark',
    autoPause: j['autoPause'] as bool? ?? true,
    weeklyDistanceGoalM:
        (j['weeklyDistanceGoalM'] as num?)?.toDouble() ?? 10000,
    weeklyRunsGoal: j['weeklyRunsGoal'] as int? ?? 3,
    nearbyAlerts: j['nearbyAlerts'] as bool? ?? true,
  );
}

/// Everything the app persists. One JSON file on disk.
class GameData {
  const GameData({
    this.user,
    this.rivals = const [],
    this.owners = const {},
    this.runs = const [],
    this.settings = const AppSettings(),
    this.home,
    this.homeState,
    this.touched = const {},
    this.following = const {},
    this.kills = 0,
    this.deaths = 0,
    this.cooldownUntil,
    this.nearbyAlerted = const {},
    this.lastExpansionDay,
    this.permissionsDone = false,
  });

  final Player? user;
  final List<Player> rivals;

  /// cellId -> playerId
  final Map<String, String> owners;
  final List<RunRecord> runs;
  final AppSettings settings;

  /// Where the world was seeded. Used for area maths and the sim start.
  final LatLng? home;

  /// Code of the Nigerian state you play in, e.g. 'LA' or 'FC'.
  /// Picked from your first GPS fix, changeable in settings.
  final String? homeState;

  /// cellId -> day number (see [epochDay]) you last claimed or ran
  /// through it. Only your own cells. Drives decay.
  final Map<String, int> touched;

  /// Player ids you follow. Shown on Home. Rivals for now; real friends
  /// once there are accounts.
  final Set<String> following;

  /// Trails you cut, and times you were cut.
  final int kills;
  final int deaths;

  /// After being cut you can't start a run until this time.
  final DateTime? cooldownUntil;

  /// playerId -> day number you were last alerted they're nearby. One
  /// alert per person per day.
  final Map<String, int> nearbyAlerted;
  final String? lastExpansionDay;
  final bool permissionsDone;

  factory GameData.empty() => const GameData();

  List<Player> get players => [if (user != null) user!, ...rivals];

  Map<String, int> get colorsById => {for (final p in players) p.id: p.color};

  Player? playerById(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  RunRecord? runById(String id) {
    for (final r in runs) {
      if (r.id == id) return r;
    }
    return null;
  }

  GameData copyWith({
    Player? user,
    List<Player>? rivals,
    Map<String, String>? owners,
    List<RunRecord>? runs,
    AppSettings? settings,
    LatLng? home,
    String? homeState,
    Map<String, int>? touched,
    Set<String>? following,
    int? kills,
    int? deaths,
    DateTime? cooldownUntil,
    Map<String, int>? nearbyAlerted,
    String? lastExpansionDay,
    bool? permissionsDone,
  }) => GameData(
    user: user ?? this.user,
    rivals: rivals ?? this.rivals,
    owners: owners ?? this.owners,
    runs: runs ?? this.runs,
    settings: settings ?? this.settings,
    home: home ?? this.home,
    homeState: homeState ?? this.homeState,
    touched: touched ?? this.touched,
    following: following ?? this.following,
    kills: kills ?? this.kills,
    deaths: deaths ?? this.deaths,
    cooldownUntil: cooldownUntil ?? this.cooldownUntil,
    nearbyAlerted: nearbyAlerted ?? this.nearbyAlerted,
    lastExpansionDay: lastExpansionDay ?? this.lastExpansionDay,
    permissionsDone: permissionsDone ?? this.permissionsDone,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'user': user?.toJson(),
    'rivals': [for (final r in rivals) r.toJson()],
    'owners': owners,
    'runs': [for (final r in runs) r.toJson()],
    'settings': settings.toJson(),
    'home': home?.toJson(),
    'homeState': homeState,
    'touched': touched,
    'following': following.toList(),
    'kills': kills,
    'deaths': deaths,
    'cooldownUntil': cooldownUntil?.toIso8601String(),
    'nearbyAlerted': nearbyAlerted,
    'lastExpansionDay': lastExpansionDay,
    'permissionsDone': permissionsDone,
  };

  factory GameData.fromJson(Map<String, dynamic> j) => GameData(
    user: j['user'] == null
        ? null
        : Player.fromJson(j['user'] as Map<String, dynamic>),
    rivals: [
      for (final r in j['rivals'] as List? ?? const [])
        Player.fromJson(r as Map<String, dynamic>),
    ],
    owners: Map<String, String>.from(j['owners'] as Map? ?? const {}),
    runs: [
      for (final r in j['runs'] as List? ?? const [])
        RunRecord.fromJson(r as Map<String, dynamic>),
    ],
    settings: j['settings'] == null
        ? const AppSettings()
        : AppSettings.fromJson(j['settings'] as Map<String, dynamic>),
    home: j['home'] == null ? null : LatLng.fromJson(j['home'] as List),
    homeState: j['homeState'] as String?,
    touched: Map<String, int>.from(j['touched'] as Map? ?? const {}),
    following: Set<String>.from(j['following'] as List? ?? const []),
    kills: j['kills'] as int? ?? 0,
    deaths: j['deaths'] as int? ?? 0,
    cooldownUntil: j['cooldownUntil'] == null
        ? null
        : DateTime.parse(j['cooldownUntil'] as String),
    nearbyAlerted: Map<String, int>.from(
      j['nearbyAlerted'] as Map? ?? const {},
    ),
    lastExpansionDay: j['lastExpansionDay'] as String?,
    permissionsDone: j['permissionsDone'] as bool? ?? false,
  );
}

/// Whole days since 1970 in local time. Used for decay and streaks.
int epochDay(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;
