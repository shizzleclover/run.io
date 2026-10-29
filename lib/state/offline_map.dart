import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../app/theme/colors.dart';
import '../core/env.dart';
import '../engine/geo.dart';

enum OfflineStatus { checking, none, downloading, ready, failed }

class OfflineMapState {
  const OfflineMapState(this.status, {this.progress = 0, this.bytes = 0});
  final OfflineStatus status;

  /// 0..1 while downloading.
  final double progress;
  final int bytes;
}

/// The map around your home, saved to the phone so it loads without data
/// and on bad signal. One region, about 4 km across each way.
final offlineMapProvider =
    NotifierProvider<OfflineMapController, OfflineMapState>(
      OfflineMapController.new,
    );

class OfflineMapController extends Notifier<OfflineMapState> {
  static const _regionId = 'home';
  static const radiusM = 4000.0;
  static const _minZoom = 11;
  static const _maxZoom = 16;

  @override
  OfflineMapState build() {
    _check();
    return const OfflineMapState(OfflineStatus.checking);
  }

  String get _styleUri =>
      AppColors.isDark ? Env.mapboxStyle : Env.mapboxStyleLight;

  Future<void> _check() async {
    try {
      final store = await mb.TileStore.createDefault();
      final regions = await store.allTileRegions();
      final home = regions.where((r) => r.id == _regionId).firstOrNull;
      state = home == null
          ? const OfflineMapState(OfflineStatus.none)
          : OfflineMapState(
              OfflineStatus.ready,
              bytes: home.completedResourceSize,
            );
    } catch (_) {
      state = const OfflineMapState(OfflineStatus.none);
    }
  }

  /// [wifiOnly] stops it from touching mobile data.
  Future<void> download(LatLng center, {required bool wifiOnly}) async {
    if (state.status == OfflineStatus.downloading) return;
    state = const OfflineMapState(OfflineStatus.downloading);
    try {
      final offline = await mb.OfflineManager.create();
      await offline.loadStylePack(
        _styleUri,
        mb.StylePackLoadOptions(acceptExpired: false),
        null,
      );

      final store = await mb.TileStore.createDefault();
      final region = await store.loadTileRegion(
        _regionId,
        mb.TileRegionLoadOptions(
          geometry: _square(center, radiusM),
          descriptorsOptions: [
            mb.TilesetDescriptorOptions(
              styleURI: _styleUri,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
            ),
          ],
          acceptExpired: true,
          networkRestriction: wifiOnly
              ? mb.NetworkRestriction.DISALLOW_EXPENSIVE
              : mb.NetworkRestriction.NONE,
        ),
        (p) {
          if (p.requiredResourceCount == 0) return;
          state = OfflineMapState(
            OfflineStatus.downloading,
            progress: p.completedResourceCount / p.requiredResourceCount,
            bytes: p.completedResourceSize,
          );
        },
      );
      state = OfflineMapState(
        OfflineStatus.ready,
        bytes: region.completedResourceSize,
      );
    } catch (_) {
      state = const OfflineMapState(OfflineStatus.failed);
    }
  }

  Future<void> remove() async {
    try {
      final store = await mb.TileStore.createDefault();
      await store.removeRegion(_regionId);
      final offline = await mb.OfflineManager.create();
      await offline.removeStylePack(_styleUri);
    } catch (_) {
      // Already gone.
    }
    state = const OfflineMapState(OfflineStatus.none);
  }

  /// GeoJSON square around [c], [r] meters from centre to each edge.
  Map<String?, Object?> _square(LatLng c, double r) {
    final n = Geo.offset(c, r, 0).lat;
    final s = Geo.offset(c, r, math.pi).lat;
    final e = Geo.offset(c, r, math.pi / 2).lng;
    final w = Geo.offset(c, r, 3 * math.pi / 2).lng;
    return {
      'type': 'Polygon',
      'coordinates': [
        [
          [w, s],
          [e, s],
          [e, n],
          [w, n],
          [w, s],
        ],
      ],
    };
  }
}
