import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../app/theme/colors.dart';
import '../../core/constants.dart';
import '../../core/env.dart';
import '../../core/live/presence.dart';
import '../../core/models.dart';
import '../../engine/geo.dart';
import '../../engine/territory_index.dart';
import '../../engine/track_point.dart';
import '../../shared/map/avatar_marker.dart';
import '../../state/game_controller.dart';
import '../../state/live_providers.dart';
import '../../state/location_providers.dart';
import '../../state/navigation.dart';
import '../../state/run_controller.dart';

const _emptyFc = '{"type":"FeatureCollection","features":[]}';

/// Your own marker always uses this image id, whatever your player id.
const _meIcon = 'avatar-me';
String _iconFor(String playerId) => 'avatar-$playerId';

/// The Mapbox map with live layers on top: hexes (territory), trail (your
/// current loop), me (your avatar), runners (other people out running,
/// with their open loops) and history (where you've run before).
class TerritoryMap extends ConsumerStatefulWidget {
  const TerritoryMap({
    super.key,
    required this.onTap,
    required this.onLongTap,
    required this.onPlayerTap,
  });

  final void Function(LatLng) onTap;
  final void Function(LatLng) onLongTap;

  /// A runner's marker (or your own) was tapped.
  final void Function(String playerId) onPlayerTap;

  @override
  ConsumerState<TerritoryMap> createState() => TerritoryMapState();
}

class TerritoryMapState extends ConsumerState<TerritoryMap> {
  mb.MapboxMap? _map;
  bool _ready = false;
  bool _centeredOnce = false;
  bool _historyVisible = false;
  LatLng? _lastPos;
  LatLng? _lastCameraPos;
  Set<String> _fresh = {};
  Timer? _freshTimer;
  Timer? _hexDebounce;

  /// Room for the start dock and map buttons under the Mapbox logo.
  static const _ornamentBottom = 150.0;

  /// Hex outlines never change, so compute each one once.
  final _ringCache = <String, List<List<double>>>{};

  /// Encoded GeoJSON per cell, reused until its look changes. Re-encoding
  /// thousands of hexes on every claim was the slow part.
  final _featureCache = <String, (String, String)>{};

  /// Regions near what's on screen. Only their hexes are sent to the map,
  /// so the cost follows the view, not the total size of the territory.
  Set<String>? _visibleRegions;
  static const _regions = RegionGrid();

  /// Past this, you're zoomed out too far for hexes to mean anything.
  static const _maxDrawnCells = 40000;

  /// playerId -> the avatar + colour its map icon was drawn with.
  final _iconKeys = <String, String>{};

  @override
  void dispose() {
    _freshTimer?.cancel();
    _hexDebounce?.cancel();
    super.dispose();
  }

  // ---------- public API for the map screen ----------

  Future<void> flyTo(LatLng p, {double zoom = 15.5, double pitch = 45}) async {
    await _map?.flyTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(p.lng, p.lat)),
        zoom: zoom,
        pitch: pitch,
      ),
      mb.MapAnimationOptions(duration: 1200),
    );
  }

  void recenter() {
    final p = _lastPos;
    if (p != null) flyTo(p, zoom: 16);
  }

  /// Make freshly claimed hexes glow for a moment.
  void flashCells(Set<String> cells) {
    _fresh = cells;
    _pushHexes();
    _freshTimer?.cancel();
    _freshTimer = Timer(const Duration(milliseconds: 1600), () {
      _fresh = {};
      _pushHexes();
    });
  }

  /// Show or hide the heatmap of your past runs.
  Future<void> setHistoryVisible(bool visible) async {
    _historyVisible = visible;
    final style = _map?.style;
    if (!_ready || style == null) return;
    if (visible) await _pushHistory();
    final v = visible ? 'visible' : 'none';
    await style.setStyleLayerProperty('history-heat', 'visibility', v);
    await style.setStyleLayerProperty('history-line', 'visibility', v);
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    ref.listen(gameProvider, (prev, next) {
      if (prev?.owners != next.owners ||
          prev?.rivals != next.rivals ||
          prev?.touched != next.touched ||
          prev?.user?.color != next.user?.color) {
        _pushHexes();
      }
      if (prev?.user?.color != next.user?.color) _applyUserColor();
      if (prev?.user != next.user || prev?.rivals != next.rivals) {
        _syncAvatars();
      }
      if (_historyVisible && prev?.runs != next.runs) _pushHistory();
    });
    ref.listen(runProvider.select((r) => r.trail), (_, _) => _pushTrail());
    ref.listen<AsyncValue<TrackPoint>>(positionProvider, (_, next) {
      if (next case AsyncData(:final value)) _onPosition(value.pos);
    });
    ref.listen<AsyncValue<List<LiveRunner>>>(liveRunnersProvider, (_, next) {
      if (next case AsyncData(:final value)) _pushRunners(value);
    });

    return mb.MapWidget(
      key: const ValueKey('territory-map'),
      styleUri: AppColors.isDark ? Env.mapboxStyle : Env.mapboxStyleLight,
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
      onMapIdleListener: (_) => _onCameraIdle(),
    );
  }

  LatLng _toLatLng(mb.Point p) =>
      LatLng(p.coordinates.lat.toDouble(), p.coordinates.lng.toDouble());

  void _onMapCreated(mb.MapboxMap map) {
    _map = map;
    map.scaleBar.updateSettings(mb.ScaleBarSettings(enabled: false));
    map.compass.updateSettings(mb.CompassSettings(enabled: false));
    // Keep the Mapbox logo and (i) visible but above the start dock.
    map.logo.updateSettings(
      mb.LogoSettings(marginLeft: 20, marginBottom: _ornamentBottom),
    );
    map.attribution.updateSettings(
      mb.AttributionSettings(marginLeft: 108, marginBottom: _ornamentBottom),
    );

    // Until GPS answers: your home or state capital, else all of Nigeria.
    final known = ref.read(fallbackCenterProvider);
    final start = known ?? kDefaultCenter;
    map.setCamera(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(start.lng, start.lat)),
        zoom: known == null ? kCountryZoom : 15,
        pitch: known == null ? 0 : 45,
      ),
    );
    map.addInteraction(
      mb.TapInteraction.onMap((context) {
        widget.onTap(_toLatLng(context.point));
      }),
    );
    map.addInteraction(
      mb.LongTapInteraction.onMap((context) {
        widget.onLongTap(_toLatLng(context.point));
      }),
    );
    // Markers win over the map tap underneath them (stopPropagation).
    for (final layer in ['runners-avatar', 'me-avatar']) {
      map.addInteraction(
        mb.TapInteraction(mb.FeaturesetDescriptor(layerId: layer), (
          feature,
          _,
        ) {
          final id = feature.properties['id'];
          if (id is String) widget.onPlayerTap(id);
        }, radius: 8),
      );
    }
  }

  Future<void> _onStyleLoaded(mb.StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;
    final style = map.style;

    for (final id in [
      'history',
      'history-lines',
      'hexes',
      'runner-trails',
      'trail',
      'runners',
      'me',
    ]) {
      if (await style.styleSourceExists(id)) continue;
      await style.addSource(
        mb.GeoJsonSource(id: id, data: _emptyFc, lineMetrics: id == 'trail'),
      );
    }

    // A new style has no images, so draw every avatar again.
    _iconKeys.clear();
    await _syncAvatars();

    final color =
        ref.read(gameProvider).user?.color ?? AppColors.playerColors.first;
    for (final layer in _layers(color)) {
      if (await style.styleLayerExists(layer['id'] as String)) continue;
      await style.addStyleLayer(jsonEncode(layer), null);
    }

    _ready = true;
    _featureCache.clear();
    await _pushHexesNow();
    await _pushTrail();
    if (_lastPos != null) await _pushMe(_lastPos!);
    if (ref.read(historyVisibleProvider)) await setHistoryVisible(true);
    final runners = ref.read(liveRunnersProvider).value;
    if (runners != null) await _pushRunners(runners);

    // Opened from another tab to look at something specific.
    final focus = ref.read(mapFocusProvider);
    if (focus != null) {
      ref.read(mapFocusProvider.notifier).clear();
      _centeredOnce = true;
      await flyTo(focus, zoom: 15);
    }
  }

  /// Layer definitions in raw Mapbox style-spec JSON, bottom to top.
  List<Map<String, dynamic>> _layers(int userColor) {
    final c = AppColors.hex(userColor);
    return [
      {
        'id': 'history-heat',
        'type': 'heatmap',
        'source': 'history',
        'layout': {'visibility': 'none'},
        'paint': {
          'heatmap-radius': [
            'interpolate', ['linear'], ['zoom'], //
            10, 6, 16, 22,
          ],
          'heatmap-intensity': [
            'interpolate', ['linear'], ['zoom'], //
            10, 0.6, 16, 1.4,
          ],
          'heatmap-opacity': 0.7,
          'heatmap-color': _heatColors(userColor),
        },
      },
      {
        'id': 'history-line',
        'type': 'line',
        'source': 'history-lines',
        'layout': {
          'visibility': 'none',
          'line-cap': 'round',
          'line-join': 'round',
        },
        'paint': {'line-color': c, 'line-width': 1.5, 'line-opacity': 0.35},
      },
      {
        'id': 'hex-fill',
        'type': 'fill',
        'source': 'hexes',
        'paint': {
          'fill-color': ['get', 'color'],
          'fill-opacity': [
            'case',
            ['get', 'fresh'],
            0.85,
            ['get', 'stale'],
            0.14,
            ['get', 'mine'],
            0.45,
            0.2,
          ],
        },
      },
      {
        'id': 'hex-line',
        'type': 'line',
        'source': 'hexes',
        'filter': [
          '==',
          ['get', 'stale'],
          false,
        ],
        'paint': {
          'line-color': ['get', 'color'],
          'line-width': 1,
          'line-opacity': [
            'case',
            ['get', 'mine'],
            0.7,
            // Rivals: fill only. Outlining every hex made the map a grid.
            0.0,
          ],
        },
      },
      // Stale land gets a dashed edge: "come back for this". Its own layer,
      // because Mapbox can't vary a dash pattern per feature.
      {
        'id': 'hex-line-stale',
        'type': 'line',
        'source': 'hexes',
        'filter': [
          '==',
          ['get', 'stale'],
          true,
        ],
        'paint': {
          'line-color': ['get', 'color'],
          'line-width': 1,
          'line-opacity': 0.5,
          'line-dasharray': [2, 2],
        },
      },
      {
        'id': 'runner-trail-line',
        'type': 'line',
        'source': 'runner-trails',
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': ['get', 'color'],
          'line-width': 4,
          'line-opacity': 0.85,
        },
      },
      {
        'id': 'trail-glow',
        'type': 'line',
        'source': 'trail',
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': c,
          'line-width': 10,
          'line-blur': 6,
          'line-opacity': 0.18,
        },
      },
      {
        'id': 'trail-line',
        'type': 'line',
        'source': 'trail',
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {'line-width': 5, 'line-gradient': _trailGradient(userColor)},
      },
      {
        'id': 'runners-avatar',
        'type': 'symbol',
        'source': 'runners',
        'layout': {
          'icon-image': ['get', 'icon'],
          'icon-anchor': 'bottom',
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
        },
      },
      {
        'id': 'me-halo',
        'type': 'circle',
        'source': 'me',
        'paint': {
          'circle-radius': 18,
          'circle-color': c,
          'circle-opacity': 0.22,
          'circle-blur': 0.6,
        },
      },
      {
        'id': 'me-avatar',
        'type': 'symbol',
        'source': 'me',
        'layout': {
          'icon-image': _meIcon,
          'icon-anchor': 'bottom',
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
        },
      },
    ];
  }

  /// Faint at the start of the loop, full brightness at your position.
  List<Object> _trailGradient(int color) => [
    'interpolate',
    ['linear'],
    ['line-progress'],
    0,
    AppColors.rgba(color, 0.15),
    1,
    AppColors.hex(color),
  ];

  List<Object> _heatColors(int color) => [
    'interpolate',
    ['linear'],
    ['heatmap-density'],
    0,
    'rgba(0,0,0,0)',
    0.2,
    AppColors.rgba(color, 0.25),
    0.6,
    AppColors.rgba(color, 0.6),
    1,
    AppColors.hex(color),
  ];

  Future<void> _applyUserColor() async {
    final style = _map?.style;
    final color = ref.read(gameProvider).user?.color;
    if (!_ready || style == null || color == null) return;
    final c = AppColors.hex(color);
    await style.setStyleLayerProperty('trail-glow', 'line-color', c);
    await style.setStyleLayerProperty(
      'trail-line',
      'line-gradient',
      _trailGradient(color),
    );
    await style.setStyleLayerProperty('me-halo', 'circle-color', c);
    await style.setStyleLayerProperty('history-line', 'line-color', c);
    await style.setStyleLayerProperty(
      'history-heat',
      'heatmap-color',
      _heatColors(color),
    );
  }

  /// Draws a map icon for you and every rival whose avatar or colour
  /// changed since last time.
  Future<void> _syncAvatars() async {
    final style = _map?.style;
    if (style == null) return;
    final game = ref.read(gameProvider);
    final user = game.user;
    final wanted = <String, Player>{
      if (user != null) _meIcon: user,
      for (final r in game.rivals) _iconFor(r.id): r,
    };
    for (final MapEntry(key: icon, value: p) in wanted.entries) {
      // Others see the public face; your own marker is always yours.
      final mine = icon == _meIcon;
      final avatar = mine ? p.avatar : p.shownAvatar;
      final key = '$avatar|${p.color}';
      if (_iconKeys[icon] == key) continue;
      _iconKeys[icon] = key;
      final image = await renderAvatarMarker(
        avatar: avatar,
        seed: p.id,
        color: Color(p.color),
      );
      await style.addStyleImage(icon, 3, image);
    }
  }

  // ---------- data pushes ----------

  Future<void> _setSource(String id, String geojson) async {
    final source = await _map?.style.getSource(id);
    if (source is mb.GeoJsonSource) await source.updateGeoJSON(geojson);
  }

  /// Several changes often land together (claim + touch + flash), so
  /// coalesce them into one update.
  void _pushHexes() {
    _hexDebounce?.cancel();
    _hexDebounce = Timer(const Duration(milliseconds: 60), _pushHexesNow);
  }

  /// Work out which regions the camera can see, and redraw if that changed.
  Future<void> _onCameraIdle() async {
    final map = _map;
    if (map == null || !mounted) return;
    final cam = await map.getCameraState();
    if (!mounted) return;
    final center = _toLatLng(cam.center);
    final size = MediaQuery.sizeOf(context);
    // Meters per logical pixel at this zoom; pitch shows more toward the
    // horizon, so pad generously.
    final mpp =
        156543.03 *
        math.cos(center.lat * math.pi / 180) /
        math.pow(2, cam.zoom);
    final halfDiagonal =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final radius = halfDiagonal * mpp * (1.3 + cam.pitch / 60);
    final regions = _regions.around(center, radius).toSet();
    if (_visibleRegions != null &&
        regions.length == _visibleRegions!.length &&
        regions.containsAll(_visibleRegions!)) {
      return;
    }
    _visibleRegions = regions;
    _pushHexes();
  }

  Future<void> _pushHexesNow() async {
    if (!_ready || !mounted) return;
    final game = ref.read(gameProvider);
    final grid = ref.read(gridProvider);
    final stale = ref.read(staleCellsProvider);
    final index = ref.read(territoryIndexProvider);
    final colors = game.colorsById;
    final me = game.user?.id;

    // Before the first camera update, draw around where we think you are.
    final regions =
        _visibleRegions ??
        _regions
            .around(
              _lastPos ?? ref.read(fallbackCenterProvider) ?? kDefaultCenter,
              3000,
            )
            .toSet();
    final visible = index.cellsIn(regions).toList();
    if (visible.length > _maxDrawnCells) {
      await _setSource('hexes', _emptyFc);
      return;
    }

    final parts = <String>[];
    for (final cell in visible) {
      final owner = game.owners[cell];
      if (owner == null) continue;
      final color = AppColors.hex(colors[owner] ?? 0xFF8A93A6);
      final mine = owner == me;
      final isStale = stale.contains(cell);
      final fresh = _fresh.contains(cell);
      final key = '$color$mine$isStale$fresh';
      final cached = _featureCache[cell];
      if (cached != null && cached.$1 == key) {
        parts.add(cached.$2);
        continue;
      }
      final ring = _ringCache.putIfAbsent(cell, () {
        final pts = [
          for (final p in grid.boundary(cell, inset: 0.07)) [p.lng, p.lat],
        ];
        return pts..add(pts.first);
      });
      final json = jsonEncode({
        'type': 'Feature',
        'properties': {
          'color': color,
          'mine': mine,
          'stale': isStale,
          'fresh': fresh,
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [ring],
        },
      });
      _featureCache[cell] = (key, json);
      parts.add(json);
    }
    _featureCache.removeWhere((cell, _) => !game.owners.containsKey(cell));

    await _setSource(
      'hexes',
      '{"type":"FeatureCollection","features":[${parts.join(',')}]}',
    );
  }

  Future<void> _pushTrail() async {
    if (!_ready) return;
    final trail = ref.read(runProvider).trail;
    if (trail.length < 2) {
      await _setSource('trail', _emptyFc);
      return;
    }
    await _setSource(
      'trail',
      jsonEncode({
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in trail) [p.lng, p.lat],
          ],
        },
      }),
    );
  }

  Future<void> _pushMe(LatLng p) async {
    if (!_ready) return;
    await _setSource(
      'me',
      jsonEncode({
        'type': 'Feature',
        'properties': {'id': ref.read(gameProvider).user?.id},
        'geometry': {
          'type': 'Point',
          'coordinates': [p.lng, p.lat],
        },
      }),
    );
  }

  Future<void> _pushRunners(List<LiveRunner> runners) async {
    if (!_ready) return;
    final game = ref.read(gameProvider);
    final points = <Map<String, dynamic>>[];
    final trails = <Map<String, dynamic>>[];
    for (final r in runners) {
      final p = game.playerById(r.playerId);
      if (p == null) continue;
      points.add({
        'type': 'Feature',
        'properties': {'icon': _iconFor(r.playerId), 'id': r.playerId},
        'geometry': {
          'type': 'Point',
          'coordinates': [r.pos.lng, r.pos.lat],
        },
      });
      if (r.trail.length >= 2) {
        trails.add({
          'type': 'Feature',
          'properties': {'color': AppColors.hex(p.color)},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final t in r.trail) [t.lng, t.lat],
            ],
          },
        });
      }
    }
    await _setSource(
      'runners',
      jsonEncode({'type': 'FeatureCollection', 'features': points}),
    );
    await _setSource(
      'runner-trails',
      jsonEncode({'type': 'FeatureCollection', 'features': trails}),
    );
  }

  Future<void> _pushHistory() async {
    if (!_ready) return;
    final runs = ref.read(gameProvider).runs;
    // Every third point is plenty for a heatmap and keeps the payload small.
    final points = [
      for (final r in runs)
        for (var i = 0; i < r.path.length; i += 3)
          [r.path[i].lng, r.path[i].lat],
    ];
    await _setSource(
      'history',
      jsonEncode({
        'type': 'Feature',
        'properties': {},
        'geometry': {'type': 'MultiPoint', 'coordinates': points},
      }),
    );
    await _setSource(
      'history-lines',
      jsonEncode({
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'MultiLineString',
          'coordinates': [
            for (final r in runs)
              if (r.path.length >= 2)
                [
                  for (final p in r.path) [p.lng, p.lat],
                ],
          ],
        },
      }),
    );
  }

  void _onPosition(LatLng p) {
    _lastPos = p;
    _pushMe(p);

    if (ref.read(runProvider).isActive) {
      // Moving the camera for every GPS jitter costs battery. Only follow
      // real movement.
      final last = _lastCameraPos;
      if (last != null && Geo.haversine(last, p) < 4) return;
      _lastCameraPos = p;
      _map?.easeTo(
        mb.CameraOptions(
          center: mb.Point(coordinates: mb.Position(p.lng, p.lat)),
          zoom: 16.5,
          pitch: 55,
        ),
        mb.MapAnimationOptions(duration: 900),
      );
    } else if (!_centeredOnce) {
      _centeredOnce = true;
      flyTo(p);
    }
  }
}
