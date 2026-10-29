import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../shared/widgets/card_format_toggle.dart';
import '../../shared/widgets/player_chip.dart';
import '../../shared/widgets/run_card.dart';
import '../../state/game_controller.dart';
import '../../app/theme/app_icons.dart';

/// Slides up after a run. The card at the top doubles as the share image.
class SummarySheet extends ConsumerStatefulWidget {
  const SummarySheet({super.key, required this.run});

  final RunRecord run;

  @override
  ConsumerState<SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends ConsumerState<SummarySheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;
  bool _story = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    final area = Fmt.area(widget.run.cells.length * ref.read(cellAreaProvider));
    try {
      await shareBoundary(
        _cardKey,
        text: 'Just claimed ${area.value} ${area.unit} on run.io',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final run = widget.run;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                run.cutBy == null ? 'Run complete' : 'You got cut',
                style: AppText.title(24),
              ),
              if (run.cutBy != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '${game.playerById(run.cutBy!)?.shownName ?? 'A rival'} ran '
                    'across your trail. All your territory is gone. You can '
                    'start again in a few minutes. Keep loops tight to stay '
                    'safe.',
                    style: AppText.body,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              CardFormatToggle(
                story: _story,
                onChanged: (v) => setState(() => _story = v),
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                key: _cardKey,
                child: RunCard(run: run, story: _story),
              ),
              if (run.stolenFrom.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Stolen from', style: AppText.section),
                const SizedBox(height: 10),
                for (final e in run.stolenFrom.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: PlayerChip(
                            name:
                                game.playerById(e.key)?.shownName ?? 'Unknown',
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
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      ref.read(gameProvider.notifier).removeRun(run.id);
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Discard'),
                  ),
                  const Spacer(),
                  Flexible(
                    child: OutlinedButton.icon(
                      onPressed: _sharing ? null : _share,
                      icon: const Icon(AppIcons.share, size: 18),
                      label: const Text(
                        'Share',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                      ),
                      child: const Text(
                        'Done',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              if (run.cells.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'No loops closed this time. Run back to where a loop '
                  'started to claim the land inside it.',
                  style: AppText.small,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
