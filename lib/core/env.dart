import 'package:flutter/foundation.dart';

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

  /// Where friends download the app, put in invites and share cards.
  /// Leave it out and invites go without a link.
  static const inviteUrl = String.fromEnvironment('INVITE_URL');

  /// Which backend: 'staging' (the server on your Mac), 'prod', or
  /// 'offline' (no accounts; ghosts run on the phone, as before).
  /// Debug builds default to staging and release builds to prod; pick one
  /// with --dart-define=APP_ENV=prod.
  static const appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: kReleaseMode ? 'prod' : 'staging',
  );

  /// On a phone over USB, `adb reverse tcp:8080 tcp:8080` makes this reach
  /// your Mac. The Android emulator uses http://10.0.2.2:8080 instead.
  static const _stagingUrl = String.fromEnvironment(
    'API_URL_STAGING',
    defaultValue: 'http://localhost:8080',
  );
  static const _prodUrl = String.fromEnvironment(
    'API_URL_PROD',
    defaultValue: 'https://api.runio.app',
  );

  /// The API for [appEnv], or empty when offline.
  static String get apiUrl => switch (appEnv) {
    'prod' => _prodUrl,
    'staging' => _stagingUrl,
    _ => '',
  };

  static bool get isStaging => appEnv == 'staging';

  static bool get hasMapboxToken => mapboxToken.isNotEmpty;
  static bool get hasApi => apiUrl.isNotEmpty;
}
