import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../state/game_controller.dart';
import 'player_avatar.dart';
import 'stat_block.dart';
import 'trail_painter.dart';
import 'wordmark.dart';

/// The run card. Shown in the summary and run detail, and it IS the share
/// image, so it's designed to look good on an Instagram story.
class RunCard extends ConsumerWidget {
  const RunCard({super.key, required this.run, this.story = false});

  final RunRecord run;

  /// 9:16 for Instagram/WhatsApp stories, with your avatar and state.
  /// Otherwise 4:5 for a feed post.
  final bool story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final grid = ref.watch(gridProvider);
    final cellArea = ref.watch(cellAreaProvider);
    final color = Color(game.user?.color ?? AppColors.playerColors.first);
    final miles = game.settings.useMiles;

    final area = Fmt.area(run.cells.length * cellArea);
    final dist = Fmt.distance(run.distanceM, miles: miles);
    final time = Duration(seconds: run.movingSeconds);
    final pace = Fmt.pace(run.distanceM, time, miles: miles);
    final cells = [for (final c in run.cells) grid.boundary(c, inset: 0.06)];
    final user = game.user;
    final place = ref.watch(homeStateProvider)?.name;

    return AspectRatio(
      aspectRatio: story ? 9 / 16 : 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Wordmark(color: color),
                const Spacer(),
                Text(Fmt.date(run.startedAt), style: AppText.small),
              ],
            ),
            if (story && user != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  PlayerAvatar(
                    avatar: user.avatar,
                    seed: user.id,
                    color: color,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title(18),
                        ),
                        if (place != null)
                          Text(
                            'Running in $place',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: TrailPainter(
                  path: run.path,
                  cells: cells,
                  color: color,
                ),
              ),
            ),
            StatBlock(
              value: area.value,
              unit: area.unit,
              label: 'Territory claimed',
              size: 44,
              color: color,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StatBlock(
                    value: dist.value,
                    unit: dist.unit,
                    label: 'Distance',
                    size: 22,
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    value: Fmt.duration(time),
                    label: 'Time',
                    size: 22,
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    value: pace.value,
                    unit: pace.unit,
                    label: 'Pace',
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders whatever is inside a RepaintBoundary to a PNG and opens the
/// native share sheet.
Future<void> shareBoundary(GlobalKey key, {required String text}) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/runio_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(bytes.buffer.asUint8List());
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: text),
  );
}
