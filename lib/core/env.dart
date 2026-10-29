/// Values passed in with --dart-define-from-file=env.json
class Env {
  Env._();

  static const mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

  /// Swap for your Mapbox Studio style URL once you've built it.
  static const mapboxStyle = String.fromEnvironment(
    'MAPBOX_STYLE',
    defaultValue: 'mapbox://styles/mapbox/dark-v11',
  );

  /// Used in light mode.
  static const mapboxStyleLight = String.fromEnvironment(
    'MAPBOX_STYLE_LIGHT',
    defaultValue: 'mapbox://styles/mapbox/light-v11',
  );

  static bool get hasMapboxToken => mapboxToken.isNotEmpty;
}
