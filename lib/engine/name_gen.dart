import 'dart:math' as math;

/// Random player names, e.g. "Yaba Falcon". Lagos places unless you pass
/// your own [places].
class NameGen {
  NameGen([math.Random? rng, List<String>? places])
    : _rng = rng ?? math.Random(),
      _placePool = places ?? _places;

  final math.Random _rng;
  final List<String> _placePool;

  static const _places = [
    'Lekki',
    'Yaba',
    'Ikoyi',
    'Surulere',
    'Ikeja',
    'Ajah',
    'Maryland',
    'Gbagada',
    'Oshodi',
    'Festac',
    'Obalende',
    'Ojota',
    'Ogba',
    'Magodo',
    'Sabo',
    'Ebute',
    'Bariga',
    'Akoka',
    'Ilupeju',
    'Anthony',
  ];

  static const _animals = [
    'Lion',
    'Falcon',
    'Panther',
    'Cheetah',
    'Hawk',
    'Wolf',
    'Viper',
    'Bull',
    'Eagle',
    'Fox',
    'Mamba',
    'Leopard',
    'Rhino',
    'Jaguar',
  ];

  String next({Set<String> exclude = const {}}) {
    for (var i = 0; i < 50; i++) {
      final name =
          '${_placePool[_rng.nextInt(_placePool.length)]} '
          '${_animals[_rng.nextInt(_animals.length)]}';
      if (!exclude.contains(name)) return name;
    }
    return 'Runner ${_rng.nextInt(999)}';
  }
}
