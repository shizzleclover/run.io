import '../engine/geo.dart';

/// Middle of Nigeria. Used when we know neither your position nor your
/// state, together with [kCountryZoom] so the whole country is in view.
const kDefaultCenter = LatLng(9.0820, 8.6753);
const kCountryZoom = 5.2;

const kAppVersion = '0.1.0';

/// How many fake rivals to seed.
const kRivalCount = 4;
