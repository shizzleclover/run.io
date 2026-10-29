import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/live/presence.dart';
import '../core/notifications.dart';
import '../shared/widgets/player_sheet.dart';
import '../state/nearby.dart';
import '../engine/track_point.dart';
import '../state/game_controller.dart';
import '../state/live_providers.dart';
import '../state/location_providers.dart';
import '../state/run_controller.dart';
import 'theme/colors.dart';
import 'theme/theme.dart';
import 'theme/app_icons.dart';

/// The bottom bar around the four tabs. Hidden during a run, so the run
/// screen gets the whole display and nothing can be mis-tapped.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _worldChecked = false;
  late final StreamSubscription<String> _taps;

  // Saves are batched, so write them out whenever the app might be killed.
  late final _lifecycle = AppLifecycleListener(
    onHide: _flush,
    onPause: _flush,
    onDetach: _flush,
  );

  void _flush() => ref.read(gameProvider.notifier).flush();

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
    // Tapping a "friend nearby" notification opens their card.
    _taps = Notifications.taps.listen((id) {
      if (mounted) showPlayerSheet(context, id);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _taps.cancel();
    super.dispose();
  }

  static const _mapTab = 1;

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    ref.watch(nearbyWatcherProvider);

    // First GPS fix, whichever tab you're on: seed rivals around you, or
    // run the daily decay and rival growth.
    ref.listen<AsyncValue<TrackPoint>>(positionProvider, (_, next) {
      if (_worldChecked) return;
      if (next case AsyncData(:final value)) {
        _worldChecked = true;
        final report = ref.read(gameProvider.notifier).ensureWorld(value.pos);
        if (report != null && !report.isEmpty) {
          _snack(
            'While you were away: ${[if (report.takenByRivals > 0) 'rivals took ${report.takenByRivals} hexes', if (report.decayed > 0) '${report.decayed} faded out'].join(', ')}',
          );
        }
      }
    });

    // The map shows its own toasts. Elsewhere, only interrupt for losses.
    ref.listen<AsyncValue<LiveEvent>>(liveEventsProvider, (_, next) {
      if (shell.currentIndex == _mapTab) return;
      if (next.value case RivalClaimed(
        :final playerId,
        :final stolenFromYou,
      ) when stolenFromYou > 0) {
        final name = ref.read(gameProvider).playerById(playerId)?.shownName;
        _snack('${name ?? 'A rival'} took $stolenFromYou of your hexes');
      }
    });

    final running = ref.watch(runProvider.select((r) => r.isActive));
    return Scaffold(
      body: shell,
      bottomNavigationBar: running
          ? null
          : NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: AppColors.bg,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                height: 60,
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => AppText.small.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.text
                        : AppColors.textMuted,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    size: 24,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.accent
                        : AppColors.textMuted,
                  ),
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: shell.currentIndex,
                  // Tapping the current tab again goes back to its root.
                  onDestinationSelected: (i) => shell.goBranch(
                    i,
                    initialLocation: i == shell.currentIndex,
                  ),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(AppIcons.home),
                      selectedIcon: Icon(AppIcons.homeActive),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(AppIcons.map),
                      selectedIcon: Icon(AppIcons.mapActive),
                      label: 'Map',
                    ),
                    NavigationDestination(
                      icon: Icon(AppIcons.ranks),
                      selectedIcon: Icon(AppIcons.ranksActive),
                      label: 'Ranks',
                    ),
                    NavigationDestination(
                      icon: Icon(AppIcons.profile),
                      selectedIcon: Icon(AppIcons.profileActive),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
