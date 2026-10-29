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

  static Future<void> nearby({
    required String playerId,
    required String name,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: playerId.hashCode & 0x7fffffff,
      title: 'A potential friend is nearby',
      body: '$name is out running near you. Say hi, or follow them.',
      notificationDetails: const NotificationDetails(android: _nearby),
      payload: playerId,
    );
  }
}
