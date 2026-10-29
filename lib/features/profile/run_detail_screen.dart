import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../shared/widgets/card_format_toggle.dart';
import '../../shared/widgets/player_chip.dart';
import '../../shared/widgets/run_card.dart';
import '../../state/game_controller.dart';
import 'splits_view.dart';
import '../../app/theme/app_icons.dart';

class RunDetailScreen extends ConsumerStatefulWidget {
  const RunDetailScreen({super.key, required this.runId});

  final String runId;

  @override
  ConsumerState<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends ConsumerState<RunDetailScreen> {
  final _cardKey = GlobalKey();
  bool _story = false;

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this run?', style: AppText.title(20)),
        content: Text(
          'The territory you claimed stays yours. Only the record goes.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(gameProvider.notifier).removeRun(widget.runId);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final run = game.runById(widget.runId);
    if (run == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Run not found', style: AppText.bodyMuted)),
      );
    }
    final area = Fmt.area(run.cells.length * ref.watch(cellAreaProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(Fmt.date(run.startedAt)),
        actions: [
          IconButton(icon: const Icon(AppIcons.delete), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          CardFormatToggle(
            story: _story,
            onChanged: (v) => setState(() => _story = v),
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _cardKey,
            child: RunCard(run: run, story: _story),
          ),
          if (run.splits.isNotEmpty) ...[
            const SizedBox(height: 24),
            SplitsView(
              splits: run.splits,
              miles: game.settings.useMiles,
              color: Color(game.user?.color ?? AppColors.playerColors.first),
            ),
          ],
          if (run.stolenFrom.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Stolen from', style: AppText.section),
            const SizedBox(height: 10),
            for (final e in run.stolenFrom.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: PlayerChip(
                        name: game.playerById(e.key)?.shownName ?? 'Unknown',
                        avatar: game.playerById(e.key)?.shownAvatar,
                        seed: e.key,
                        color: Color(
                          game.playerById(e.key)?.color ?? 0xFF8A93A6,
                        ),
                      ),
                    ),
                    Text('${e.value} hexes', style: AppText.small),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => shareBoundary(
              _cardKey,
              text: 'Claimed ${area.value} ${area.unit} on run.io',
            ),
            icon: const Icon(AppIcons.share, size: 18),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
