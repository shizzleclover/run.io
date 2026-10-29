import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/round_button.dart';
import '../../shared/widgets/stat_block.dart';
import '../../state/game_controller.dart';
import '../../state/run_controller.dart';
import '../../app/theme/app_icons.dart';

/// Everything on top of the map while a run is active.
class RunOverlay extends ConsumerWidget {
  const RunOverlay({super.key, required this.onRecenter});

  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(runProvider);
    final game = ref.watch(gameProvider);
    final cellArea = ref.watch(cellAreaProvider);
    final controller = ref.read(runProvider.notifier);
    final color = Color(game.user?.color ?? AppColors.playerColors.first);
    final miles = game.settings.useMiles;
    final haptics = game.settings.haptics;

    final dist = Fmt.distance(run.distanceM, miles: miles);
    final pace = Fmt.pace(run.distanceM, run.elapsed, miles: miles);
    final area = Fmt.area(run.claimedCells.length * cellArea);
    final paused = run.status == RunStatus.paused;
    final stopped = paused || run.autoPaused;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            GlassCard(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: StatBlock(
                          value: Fmt.duration(run.elapsed),
                          label: paused
                              ? 'Paused'
                              : run.autoPaused
                              ? 'Auto-paused'
                              : 'Time',
                          size: 48,
                          color: stopped
                              ? AppColors.textSecondary
                              : AppColors.text,
                        ),
                      ),
                      StatBlock(
                        value: dist.value,
                        unit: dist.unit,
                        label: 'Distance',
                        size: 28,
                        align: CrossAxisAlignment.end,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: StatBlock(
                          value: pace.value,
                          unit: pace.unit,
                          label: 'Pace',
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: area.value,
                          unit: area.unit,
                          label: 'Claimed',
                          size: 20,
                          color: color,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          value: '${run.stolenTotal}',
                          label: 'Stolen',
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (run.weakGps)
              const _Banner(
                icon: AppIcons.weakGps,
                text: 'Weak GPS. Hold on, finding you.',
                color: AppColors.warning,
              )
            else if (run.nearClose)
              _Pulse(
                child: _Banner(
                  icon: AppIcons.loop,
                  text: 'Close the loop!',
                  color: AppColors.accent,
                ),
              ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MapIconButton(
                  icon: AppIcons.recenter,
                  label: 'Centre on me',
                  onTap: onRecenter,
                ),
                const SizedBox(width: 24),
                RoundButton(
                  size: 76,
                  color: paused ? AppColors.accent : AppColors.elevated,
                  foreground: paused ? AppColors.onAccent : AppColors.text,
                  glow: paused,
                  icon: paused ? AppIcons.play : AppIcons.pause,
                  semanticLabel: paused ? 'Resume run' : 'Pause run',
                  onTap: () {
                    if (haptics) HapticFeedback.lightImpact();
                    paused ? controller.resume() : controller.pause();
                  },
                ),
                const SizedBox(width: 24),
                RoundButton(
                  size: 56,
                  color: AppColors.danger,
                  foreground: Colors.white,
                  glow: false,
                  icon: AppIcons.stop,
                  semanticLabel: 'Stop run. Hold to stop.',
                  onTap: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Hold to stop the run')),
                    ),
                  onLongPress: () {
                    if (haptics) HapticFeedback.heavyImpact();
                    controller.stop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 30,
      borderColor: color.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.ink(color), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: AppText.body.copyWith(
                color: AppColors.ink(color),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.55, end: 1.0).animate(_c),
    child: ScaleTransition(
      scale: Tween(begin: 0.97, end: 1.03).animate(_c),
      child: widget.child,
    ),
  );
}
