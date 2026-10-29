import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/env.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../state/game_controller.dart';
import '../../state/navigation.dart';

/// GitHub-style grid of the last [weeks] weeks: one square per day, shaded
/// by how far you ran. Columns are weeks, Monday at the top.
class ActivityCalendar extends ConsumerWidget {
  const ActivityCalendar({super.key, this.weeks = 16});

  final int weeks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(gameProvider.select((g) => g.runs));
    final miles = ref.watch(gameProvider.select((g) => g.settings.useMiles));

    final perDay = <int, double>{};
    for (final r in runs) {
      final d = epochDay(r.startedAt);
      perDay[d] = (perDay[d] ?? 0) + r.distanceM;
    }
    final now = DateTime.now();
    final today = epochDay(now);
    // First column starts on a Monday, so rows line up with weekdays.
    final firstDay = today - (now.weekday - 1) - (weeks - 1) * 7;
    final max = perDay.values.fold(0.0, math.max);
    final activeDays = perDay.keys.where((d) => d >= firstDay).length;
    final total = Fmt.distance(
      perDay.entries
          .where((e) => e.key >= firstDay)
          .fold(0.0, (a, e) => a + e.value),
      miles: miles,
    );

    Color shade(double m) {
      if (m <= 0 || max <= 0) return AppColors.elevated;
      final t = (m / max).clamp(0.0, 1.0);
      final alpha = t < 0.25
          ? 0.3
          : t < 0.5
          ? 0.5
          : t < 0.75
          ? 0.75
          : 1.0;
      return AppColors.accent.withValues(alpha: alpha);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity', style: AppText.section),
        const SizedBox(height: AppSpace.xs),
        Text(
          '$activeDays active days · ${total.value} ${total.unit} in '
          '$weeks weeks',
          style: AppText.small,
        ),
        const SizedBox(height: AppSpace.md),
        LayoutBuilder(
          builder: (context, box) {
            const gap = 3.0;
            final cell = (box.maxWidth - gap * (weeks - 1)) / weeks;
            return Semantics(
              label: '$activeDays active days in the last $weeks weeks',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var w = 0; w < weeks; w++) ...[
                    if (w > 0) const SizedBox(width: gap),
                    Column(
                      children: [
                        for (var d = 0; d < 7; d++) ...[
                          if (d > 0) const SizedBox(height: gap),
                          _Day(
                            size: cell,
                            day: firstDay + w * 7 + d,
                            today: today,
                            color: shade(perDay[firstDay + w * 7 + d] ?? 0),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: AppText.small),
            const SizedBox(width: AppSpace.xs),
            for (final a in [0.0, 0.3, 0.5, 0.75, 1.0]) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: a == 0
                      ? AppColors.elevated
                      : AppColors.accent.withValues(alpha: a),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 2),
            ],
            const SizedBox(width: AppSpace.xs),
            Text('More', style: AppText.small),
          ],
        ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.size,
    required this.day,
    required this.today,
    required this.color,
  });

  final double size;
  final int day;
  final int today;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Days that haven't happened yet are left blank.
    if (day > today) return SizedBox(width: size, height: size);
    return AnimatedContainer(
      duration: AppMotion.base,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: day == today
            ? Border.all(color: AppColors.textSecondary, width: 1)
            : null,
      ),
    );
  }
}

/// A still map of where you've run, routes glowing hotter where you run
/// most. Drawn once off-screen (Mapbox Snapshotter) instead of a second
/// live map, which would cost memory and battery on Home. Tap to open the
/// Map tab with the history layer on.
class RouteHeatmap extends ConsumerStatefulWidget {
  const RouteHeatmap({super.key});

  @override
  ConsumerState<RouteHeatmap> createState() => _RouteHeatmapState();
}

class _RouteHeatmapState extends ConsumerState<RouteHeatmap> {
  /// Last image, kept across rebuilds and tab switches.
  static Uint8List? _cached;
  static String? _cachedKey;

  Future<Uint8List?>? _future;
  String? _key;

  @override
  Widget build(BuildContext context) {
    final runs = ref.watch(gameProvider.select((g) => g.runs));
    final color = AppColors.playerColors.first;
    final userColor =
        ref.watch(gameProvider.select((g) => g.user?.color)) ?? color;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where you run', style: AppText.section),
        const SizedBox(height: AppSpace.md),
        AspectRatio(
          aspectRatio: 16 / 10,
          child: LayoutBuilder(
            builder: (context, box) {
              if (runs.isEmpty) return const _Empty();
              final key =
                  '${runs.length}|${AppColors.isDark}|$userColor|'
                  '${box.maxWidth.round()}';
              if (key != _key) {
                _key = key;
                _future = key == _cachedKey
                    ? Future.value(_cached)
                    : _render(runs, box.biggest, dpr, userColor).then((b) {
                        _cached = b;
                        _cachedKey = key;
                        return b;
                      });
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Material(
                  color: AppColors.surface,
                  child: InkWell(
                    onTap: () {
                      ref.read(historyVisibleProvider.notifier).set(true);
                      context.go('/map');
                    },
                    child: FutureBuilder<Uint8List?>(
                      future: _future,
                      builder: (context, snap) {
                        final bytes = snap.data;
                        return AnimatedSwitcher(
                          duration: AppMotion.slow,
                          child: bytes == null
                              ? const SizedBox.expand(key: ValueKey('wait'))
                              : Stack(
                                  key: const ValueKey('map'),
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(bytes, fit: BoxFit.cover),
                                    const Positioned(
                                      right: AppSpace.md,
                                      bottom: AppSpace.md,
                                      child: _OpenChip(),
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Snapshot of the map around your runs with a heatmap layer on top.
  static Future<Uint8List?> _render(
    List<RunRecord> runs,
    Size size,
    double dpr,
    int color,
  ) async {
    final points = <List<double>>[
      for (final r in runs)
        for (var i = 0; i < r.path.length; i += 3)
          [r.path[i].lng, r.path[i].lat],
    ];
    if (points.isEmpty) return null;

    final loaded = Completer<void>();
    final snap = await mb.Snapshotter.create(
      options: mb.MapSnapshotOptions(
        size: mb.Size(width: size.width, height: size.height),
        pixelRatio: dpr,
        showsLogo: false,
        showsAttribution: false,
      ),
      onStyleLoadedListener: (_) {
        if (!loaded.isCompleted) loaded.complete();
      },
    );
    try {
      await snap.setStyleURI(
        AppColors.isDark ? Env.mapboxStyle : Env.mapboxStyleLight,
      );
      await loaded.future.timeout(const Duration(seconds: 15));
      await snap.addSource(
        mb.GeoJsonSource(
          id: 'history',
          data: jsonEncode({
            'type': 'Feature',
            'properties': {},
            'geometry': {'type': 'MultiPoint', 'coordinates': points},
          }),
        ),
      );
      await snap.addStyleLayer(
        jsonEncode({
          'id': 'history-heat',
          'type': 'heatmap',
          'source': 'history',
          'paint': {
            'heatmap-radius': 14,
            'heatmap-intensity': 1.1,
            'heatmap-opacity': 0.85,
            'heatmap-color': [
              'interpolate',
              ['linear'],
              ['heatmap-density'],
              0,
              'rgba(0,0,0,0)',
              0.2,
              AppColors.rgba(color, 0.3),
              0.6,
              AppColors.rgba(color, 0.7),
              1,
              AppColors.hex(color),
            ],
          },
        }),
        null,
      );
      final camera = await snap.camera(
        coordinates: [
          for (final p in points)
            mb.Point(coordinates: mb.Position(p[0], p[1])),
        ],
        padding: mb.MbxEdgeInsets(top: 32, left: 32, bottom: 32, right: 32),
        bearing: 0,
        pitch: 0,
      );
      // Don't zoom in past street level for a single short run.
      camera.zoom = math.min(camera.zoom ?? 14, 15.5);
      await snap.setCamera(camera);
      return await snap.start();
    } catch (_) {
      return null;
    } finally {
      await snap.dispose();
    }
  }
}

class _OpenChip extends StatelessWidget {
  const _OpenChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Open map',
          style: AppText.small.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Icon(AppIcons.forward, size: 14, color: AppColors.text),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(AppSpace.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.history, size: 28, color: AppColors.textMuted),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Your runs will glow here.',
          style: AppText.small,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
