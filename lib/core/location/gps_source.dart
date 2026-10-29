import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../engine/track_point.dart';
import 'location_source.dart';

class GpsSource implements LocationSource {
  GpsSource({required this.background});

  /// When true (during a run) Android runs a foreground service with a
  /// notification and iOS keeps updating with the screen off.
  final bool background;

  @override
  Stream<TrackPoint> get points =>
      Geolocator.getPositionStream(locationSettings: _settings()).map(
        (p) => TrackPoint(
          lat: p.latitude,
          lng: p.longitude,
          accuracy: p.accuracy,
          timestamp: p.timestamp,
        ),
      );

  LocationSettings _settings() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: background
              ? const ForegroundNotificationConfig(
                  notificationTitle: 'run.io is tracking your run',
                  notificationText: 'Close loops to claim territory',
                  enableWakeLock: true,
                )
              : null,
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.fitness,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: background,
          allowBackgroundLocationUpdates: background,
        );
      default:
        return const LocationSettings(accuracy: LocationAccuracy.best);
    }
  }

  @override
  void dispose() {}
}
