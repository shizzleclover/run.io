import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../core/live/presence.dart';
import '../../core/models.dart';
import '../../engine/geo.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/player_avatar.dart';
import '../../shared/widgets/player_sheet.dart';
import '../../state/game_controller.dart';
import '../../state/live_providers.dart';
import '../../state/navigation.dart';
import '../../state/location_providers.dart';
import '../../state/run_controller.dart';
import '../run/run_overlay.dart';
import '../summary/summary_sheet.dart';
import 'territory_map.dart';
import '../../app/theme/app_icons.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _Toast {
  _Toast(this.title, this.subtitle, this.color);
  final String title;
  final String? subtitle;
  final Color color;
  final Key key = UniqueKey();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapKey = GlobalKey<TerritoryMapState>();
  _Toast? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 3, 2, 1 before a run starts. Null when not counting.
  int? _countdown;
  Timer? _countdownTimer;

  void _beginCountdown() {
    if (_countdown != null) return;
    final haptics = ref.read(gameProvider).settings.haptics;
    if (haptics) HapticFeedback.mediumImpact();
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final next = _countdown! - 1;
      if (next == 0) {
        t.cancel();
        setState(() => _countdown = null);
        if (haptics) HapticFeedback.heavyImpact();
        ref.read(runProvider.notifier).start();
        return;
      }
      if (haptics) HapticFeedback.selectionClick();
      setState(() => _countdown = next);
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = null);
  }

  void _showToast(String title, {String? subtitle, required Color color}) {
    setState(() => _toast = _Toast(title, subtitle, color));
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _onTap(LatLng p) {
    if (ref.read(gameProvider).settings.simMode) {
      ref.read(simSourceProvider).moveTo(p);
    } else {
      _showOwner(p);
    }
  }

  void _showOwner(LatLng p) {
    final game = ref.read(gameProvider);
    final cell = ref.read(gridProvider).cellAt(p);
    final ownerId = game.owners[cell];
    final owner = ownerId == null ? null : game.playerById(ownerId);
    if (owner == null) {
      _showToast(
        'Unclaimed land',
        subtitle: 'Run a loop around it',
        color: AppColors.textSecondary,
      );
    } else if (owner.id == game.user?.id) {
      _showToast('Yours', subtitle: 'Defend it', color: Color(owner.color));
    } else {
      _showToast(
        owner.name,
        subtitle: 'Take it from them',
        color: Color(owner.color),
      );
    }
  }

  void _openSummary(RunRecord run) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SummarySheet(run: run),
    ).whenComplete(() => ref.read(runProvider.notifier).dismissSummary());
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final run = ref.watch(runProvider);
    final position = ref.watch(positionProvider);
    final cooldown = ref.watch(cooldownProvider).value;
    final cellArea = ref.watch(cellAreaProvider);
    final history = ref.watch(historyVisibleProvider);
    ref.listen<bool>(historyVisibleProvider, (_, v) {
      _mapKey.currentState?.setHistoryVisible(v);
    });

    // Another tab asked to show a place (leaderboard, live runner, …).
    ref.listen<LatLng?>(mapFocusProvider, (_, target) {
      if (target == null) return;
      ref.read(mapFocusProvider.notifier).clear();
      _mapKey.currentState?.flyTo(target, zoom: 15);
    });

    // Live runners: claims, and cuts either way.
    ref.listen<AsyncValue<LiveEvent>>(liveEventsProvider, (_, next) {
      final e = next.value;
      if (e == null) return;
      final g = ref.read(gameProvider);
      final who = g.playerById(e.playerId);
      final name = who?.shownName ?? 'A rival';
      final theirColor = Color(who?.color ?? 0xFF8A93A6);
      final haptics = g.settings.haptics;
      switch (e) {
        case RivalClaimed(:final stolenFromYou) when stolenFromYou > 0:
          if (haptics) HapticFeedback.heavyImpact();
          _showToast(
            '$name hit you',
            subtitle: 'Took $stolenFromYou of your hexes. Take them back.',
            color: theirColor,
          );
        case RivalClaimed(:final cells):
          _showToast(
            '$name claimed land',
            subtitle: '$cells hexes nearby',
            color: theirColor,
          );
        case YouCut():
          if (haptics) HapticFeedback.mediumImpact();
          _showToast(
            'You cut $name',
            subtitle: 'They\'re out. All their land is gone.',
            color: Color(g.user?.color ?? AppColors.playerColors.first),
          );
        case CutYou():
          if (haptics) HapticFeedback.heavyImpact();
          _showToast(
            '$name cut you',
            subtitle: 'You\'re out. All your land is gone.',
            color: AppColors.danger,
          );
      }
    });

    // Loop closed: haptic, glow, toast.
    ref.listen(runProvider.select((r) => r.lastClaim), (prev, next) {
      if (next == null || next.id == prev?.id) return;
      if (ref.read(gameProvider).settings.haptics)
        HapticFeedback.mediumImpact();
      _mapKey.currentState?.flashCells(next.cells);
      final area = Fmt.area(next.cells.length * ref.read(cellAreaProvider));
      String? sub;
      if (next.stolenFrom.isNotEmpty) {
        final top = next.stolenFrom.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );
        final victim = ref.read(gameProvider).playerById(top.key);
        sub = 'Took ${top.value} hexes from ${victim?.shownName ?? 'a rival'}';
      }
      final me = ref.read(gameProvider).user;
      _showToast(
        '+${area.value} ${area.unit}',
        subtitle: sub,
        color: Color(me?.color ?? AppColors.playerColors.first),
      );
    });

    // Run stopped: open the summary.
    ref.listen(runProvider.select((r) => r.finished), (prev, next) {
      if (next != null && next.id != prev?.id) _openSummary(next);
    });

    // Briefly null while wiping data, before the router moves on.
    final user = game.user;
    if (user == null) return const Scaffold();

    final myCells = game.owners.values.where((o) => o == user.id).length;
    final myArea = Fmt.area(myCells * cellArea);
    final fix = switch (position) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final gps = game.settings.simMode
        ? _Gps.sim
        : fix == null
        ? _Gps.searching
        : fix.accuracy <= 15
        ? _Gps.good
        : fix.accuracy <= 25
        ? _Gps.ok
        : _Gps.weak;
    final live = ref.watch(liveRunnersProvider).value ?? const [];
    final nearby = fix == null
        ? 0
        : live.where((r) => Geo.haversine(r.pos, fix.pos) < 1000).length;

    // Home's Start button lands here and goes through the countdown too.
    if (ref.watch(startRequestProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(startRequestProvider.notifier).consume();
        if (!ref.read(runProvider).isActive && cooldown == null) {
          _beginCountdown();
        }
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TerritoryMap(
              key: _mapKey,
              onTap: _onTap,
              onLongTap: _showOwner,
              onPlayerTap: (id) => showPlayerSheet(context, id),
            ),
          ),

          if (run.isActive)
            Positioned.fill(
              child: RunOverlay(
                onRecenter: () => _mapKey.currentState?.recenter(),
              ),
            )
          else ...[
            // Top: who you are, how much you own, whether GPS is good.
            Positioned(
              top: 0,
              left: AppSpace.lg,
              right: AppSpace.lg,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _TopBar(
                      user: user,
                      area: myArea,
                      gps: gps,
                      onTap: () => showPlayerSheet(context, user.id),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom: map buttons, then the dock.
            Positioned(
              left: AppSpace.lg,
              right: AppSpace.lg,
              bottom: AppSpace.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MapIconButton(
                    icon: history ? AppIcons.historyOn : AppIcons.history,
                    label: history ? 'Hide run history' : 'Show run history',
                    active: history,
                    onTap: () =>
                        ref.read(historyVisibleProvider.notifier).set(!history),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  MapIconButton(
                    icon: AppIcons.recenter,
                    label: 'Centre on me',
                    onTap: () => _mapKey.currentState?.recenter(),
                  ),
                  const SizedBox(height: AppSpace.md),
                  _Dock(
                    gps: gps,
                    nearby: nearby,
                    cooldown: cooldown,
                    locationError: position.hasError,
                    onStart: _beginCountdown,
                    onFixLocation: () => context.push('/permissions'),
                  ),
                ],
              ),
            ),
          ],

          if (_countdown != null)
            Positioned.fill(
              child: _Countdown(value: _countdown!, onCancel: _cancelCountdown),
            ),

          // Toast
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(top: run.isActive ? 200 : 64),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position:
                        Tween(
                          begin: const Offset(0, -0.4),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: _toast == null
                      ? const SizedBox.shrink()
                      : Center(
                          key: _toast!.key,
                          child: GlassCard(
                            radius: 18,
                            borderColor: _toast!.color.withValues(alpha: 0.6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _toast!.title,
                                  style: AppText.number(
                                    22,
                                    color: AppColors.ink(_toast!.color),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (_toast!.subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _toast!.subtitle!,
                                    style: AppText.small,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How usable the current location is for a run.
enum _Gps {
  searching('Finding GPS…', Color(0xFF8A8F98)),
  weak('Weak GPS', AppColors.danger),
  ok('GPS ok', AppColors.warning),
  good('GPS ready', AppColors.ok),
  sim('Simulator', AppColors.warning);

  const _Gps(this.label, this.color);
  final String label;
  final Color color;

  /// You can start with a weak fix (the run waits for a better one), but
  /// not with no fix at all.
  bool get canStart => this != _Gps.searching;
}

/// Avatar, name and land in one pill; a dot on the avatar shows GPS.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.user,
    required this.area,
    required this.gps,
    required this.onTap,
  });

  final Player user;
  final Formatted area;
  final _Gps gps;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${user.name}, ${area.value} ${area.unit} owned, ${gps.label}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(
            AppSpace.sm,
            AppSpace.sm,
            AppSpace.lg,
            AppSpace.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  PlayerAvatar(
                    avatar: user.avatar,
                    seed: user.id,
                    color: Color(user.color),
                    size: AppSize.avatarSm,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: gps.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpace.md),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: area.value, style: AppText.number(15)),
                          TextSpan(
                            text: ' ${area.unit} owned',
                            style: AppText.unit(12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything about starting a run, in one place at the bottom: is GPS
/// ready, who's around, and the button itself.
class _Dock extends StatelessWidget {
  const _Dock({
    required this.gps,
    required this.nearby,
    required this.cooldown,
    required this.locationError,
    required this.onStart,
    required this.onFixLocation,
  });

  final _Gps gps;
  final int nearby;
  final Duration? cooldown;
  final bool locationError;
  final VoidCallback onStart;
  final VoidCallback onFixLocation;

  @override
  Widget build(BuildContext context) {
    final cut = cooldown != null;
    final canStart = !locationError && !cut && gps.canStart;

    final (String label, IconData icon) = locationError
        ? ('Location is off', AppIcons.locationOff)
        : cut
        ? ('Back in ${Fmt.duration(cooldown!)}', AppIcons.cooldown)
        : ('Start run', AppIcons.play);

    return GlassCard(
      radius: AppRadius.lg + 4,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status line
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xs,
              AppSpace.xs,
              AppSpace.xs,
              AppSpace.md,
            ),
            child: Row(
              children: [
                _Status(color: gps.color, text: gps.label),
                const Spacer(),
                if (locationError)
                  GestureDetector(
                    onTap: onFixLocation,
                    child: Text(
                      'Fix',
                      style: AppText.small.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  AnimatedSwitcher(
                    duration: AppMotion.base,
                    child: Text(
                      cut
                          ? 'You got cut. Start from zero.'
                          : nearby == 0
                          ? 'No runners nearby'
                          : nearby == 1
                          ? '1 runner nearby'
                          : '$nearby runners nearby',
                      key: ValueKey('$cut$nearby'),
                      style: AppText.small,
                    ),
                  ),
              ],
            ),
          ),
          _StartButton(
            label: label,
            icon: icon,
            enabled: canStart,
            // Waiting on a first fix: say so with motion, not more words.
            busy: !locationError && !cut && !gps.canStart,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedContainer(
        duration: AppMotion.base,
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpace.sm),
      Text(
        text,
        style: AppText.small.copyWith(
          color: AppColors.text,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

/// The wide Start pill. It presses in when touched and its label slides
/// between states (Finding GPS → Start run).
class _StartButton extends StatefulWidget {
  const _StartButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    return Semantics(
      button: true,
      enabled: on,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapUp: on ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: on ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          child: AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.curve,
            height: 60,
            decoration: BoxDecoration(
              color: on ? AppColors.accent : AppColors.elevated,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.base,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(a),
                        child: child,
                      ),
                    ),
                    child: Align(
                      key: ValueKey(widget.label),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(
                          18,
                          color: on
                              ? AppColors.onAccent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: on
                        ? AppColors.onAccent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: widget.busy
                      ? Padding(
                          padding: const EdgeInsets.all(9),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : Icon(
                          widget.icon,
                          size: 18,
                          color: on
                              ? AppColors.onAccent
                              : AppColors.textSecondary,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3, 2, 1 over a dimmed map, then the run starts. Time to pocket the
/// phone; tap Cancel to back out.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.value, required this.onCancel});

  final int value;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.base,
      builder: (context, fade, child) => Opacity(opacity: fade, child: child),
      child: ColoredBox(
        color: AppColors.bg.withValues(alpha: 0.96),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Text('Get ready', style: AppText.bodyMuted),
              const SizedBox(height: AppSpace.md),
              SizedBox(
                height: 180,
                child: AnimatedSwitcher(
                  duration: AppMotion.base,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 1.6, end: 1.0).animate(
                        CurvedAnimation(parent: a, curve: AppMotion.curve),
                      ),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '$value',
                    key: ValueKey(value),
                    style: AppText.number(150, color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'Close a loop to claim the land inside',
                style: AppText.small,
              ),
              const Spacer(),
              // Where your thumb already is: the Start button's spot.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.screen + AppSpace.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xxl + AppSpace.sm),
            ],
          ),
        ),
      ),
    );
  }
}
