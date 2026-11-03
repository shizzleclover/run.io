import '../engine/geo.dart';

/// Middle of Nigeria. Used when we know neither your position nor your
/// state, together with [kCountryZoom] so the whole country is in view.
const kDefaultCenter = LatLng(9.0820, 8.6753);
const kCountryZoom = 5.2;

/// Keep in step with `version:` in pubspec.yaml. The server's
/// MIN_APP_VERSION is compared against this.
const kAppVersion = '1.0.0';

/// How many fake rivals to seed.
const kRivalCount = 4;

/// Ghosts start retreating as real runners arrive in an area, and are all
/// gone once this many are playing there.
const kGhostRetreatRunners = 10;
