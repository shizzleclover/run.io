import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Phone notifications. Today: "a potential friend is nearby". Taps come
/// back through [taps] with the player id, so the app can open their card.
class Notifications {
  Notifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _taps = StreamController<String>.broadcast();
  static bool _ready = false;

  static Stream<String> get taps => _taps.stream;

  static const _nearby = AndroidNotificationDetails(
    'nearby',
    'Runners nearby',
    channelDescription: 'When a runner you could befriend is close to you',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.social,
  );

  static Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final id = r.payload;
        if (id != null) _taps.add(id);
      },
    );
    _ready = true;
  }

  /// Android 13+ asks the user. Returns whether we may notify.
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  static const _game = AndroidNotificationDetails(
    'game',
    'Your land and crew',
    channelDescription: 'Land taken, new followers, crew news',
    importance: Importance.defaultImportance,
    category: AndroidNotificationCategory.social,
  );

  /// Something from the server: a follower, a crewmate, an invite.
  static Future<void> message({
    required String title,
    required String body,
    String? playerId,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _game),
      payload: playerId,
    );
  }

  /// A real runner is "a potential friend". A ghost is only ever called
  /// a ghost: never pass one off as a person.
  static Future<void> nearby({
    required String playerId,
    required String name,
    bool ghost = false,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: playerId.hashCode & 0x7fffffff,
      title: ghost
          ? 'A ghost runner is on your turf'
          : 'A potential friend is nearby',
      body: ghost
          ? '$name is out running near you. Cut their trail before they '
                'close a loop.'
          : '$name is out running near you. Say hi, or follow them.',
      notificationDetails: const NotificationDetails(android: _nearby),
      payload: playerId,
    );
  }
}
