/// Tunable game constants. Tweak these after real test runs in Lagos.
class EngineConfig {
  EngineConfig._();

  /// Drop GPS points with worse accuracy than this (meters).
  static const double maxAccuracyM = 25;

  /// Faster than this is a vehicle, not a runner (m/s). ~25 km/h.
  static const double maxSpeedMps = 7;

  /// Ignore movements smaller than this (meters). Kills standing-still jitter.
  static const double minStepM = 3;

  /// A loop closes if you come back within this distance of an earlier point.
  static const double closeRadiusM = 25;

  /// A loop must be at least this long (meters) before it can close.
  static const double minLoopLengthM = 200;

  /// Show the "close the loop" hint inside this distance.
  static const double nearCloseRadiusM = 50;

  /// Hex size in Web Mercator meters (center to corner). ~30m in Lagos.
  static const double hexSizeMercator = 30;

  /// A loop must contain at least this many hexes to count.
  static const int minClaimCells = 3;

  // ---------- cuts (Paper.io, hardcore) ----------

  /// Trail older than this can't be cut any more.
  static const Duration trailTtl = Duration(minutes: 15);

  /// After being cut, how long before you can run again.
  static const Duration cutCooldown = Duration(minutes: 5);

  /// Both runners need GPS at least this good for a cut to count (meters).
  static const double cutMaxAccuracyM = 15;

  /// Runners who start within this distance and time of each other are a
  /// group and can't cut each other.
  static const double groupRadiusM = 20;
  static const Duration groupWindow = Duration(minutes: 1);

  /// The newest few trail points never count as crossed: that's just
  /// someone running right behind or beside you.
  static const int cutTipPoints = 2;

  /// Coarse grid for regions (loading, live channels), center to corner in
  /// Web Mercator meters. ~3 km across in Nigeria.
  static const double regionSizeMercator = 1700;
}
