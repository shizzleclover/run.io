import '../engine/geo.dart';

/// A launch area: a campus or neighbourhood small enough that a few dozen
/// runners fill it. Leaderboards and "who's here" are scoped to your area,
/// so a new player is ranked against the people around them, not a city.
///
/// Rolled out one at a time: add an area here when you start inviting
/// runners there. Centres are approximate; check them on the map before
/// a launch.
class LaunchArea {
  const LaunchArea(
    this.id,
    this.name,
    this.short,
    this.center, {
    this.radiusM = 2500,
  });

  final String id;
  final String name;

  /// Used in tight spots: "#3 in UI".
  final String short;
  final LatLng center;
  final double radiusM;

  bool contains(LatLng p) => Geo.haversine(center, p) <= radiusM;
}

const kLaunchAreas = <LaunchArea>[
  // Campuses
  LaunchArea('ui', 'University of Ibadan', 'UI', LatLng(7.4443, 3.8995)),
  LaunchArea('oau', 'OAU Ile-Ife', 'OAU', LatLng(7.5186, 4.5266)),
  LaunchArea('unilag', 'UNILAG Akoka', 'UNILAG', LatLng(6.5155, 3.3972)),
  LaunchArea('unn', 'UNN Nsukka', 'UNN', LatLng(6.8667, 7.4083)),
  LaunchArea('abu', 'ABU Zaria', 'ABU', LatLng(11.1524, 7.6544)),
  LaunchArea('uniben', 'UNIBEN Ugbowo', 'UNIBEN', LatLng(6.4000, 5.6170)),
  LaunchArea('unilorin', 'UNILORIN', 'UNILORIN', LatLng(8.4823, 4.6729)),
  LaunchArea('futa', 'FUTA Akure', 'FUTA', LatLng(7.3046, 5.1360)),
  LaunchArea('uniport', 'UNIPORT Choba', 'UNIPORT', LatLng(4.9069, 6.9170)),
  LaunchArea('cu', 'Covenant University', 'CU', LatLng(6.6718, 3.1581)),
  // Neighbourhoods
  LaunchArea('lekki1', 'Lekki Phase 1', 'Lekki', LatLng(6.4478, 3.4723)),
  LaunchArea('ikoyi', 'Ikoyi', 'Ikoyi', LatLng(6.4520, 3.4350)),
  LaunchArea('vi', 'Victoria Island', 'VI', LatLng(6.4281, 3.4219)),
  LaunchArea('surulere', 'Surulere', 'Surulere', LatLng(6.5000, 3.3500)),
  LaunchArea('wuse', 'Wuse', 'Wuse', LatLng(9.0790, 7.4700)),
  LaunchArea('jabi', 'Jabi', 'Jabi', LatLng(9.0700, 7.4250)),
];

/// When you're not in a launch area, "near you" means this radius.
const kNearbyAreaRadiusM = 3000.0;

/// The launch area [p] is in, closest first if two overlap.
LaunchArea? areaAt(LatLng p) {
  LaunchArea? best;
  var bestD = double.infinity;
  for (final a in kLaunchAreas) {
    final d = Geo.haversine(a.center, p);
    if (d <= a.radiusM && d < bestD) {
      best = a;
      bestD = d;
    }
  }
  return best;
}
