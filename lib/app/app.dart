import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env.dart';
import '../state/account.dart';
import '../state/cloud_sync.dart';
import '../state/game_controller.dart';
import 'router.dart';
import 'theme/colors.dart';
import 'theme/theme.dart';

class RunIoApp extends ConsumerStatefulWidget {
  const RunIoApp({super.key});

  @override
  ConsumerState<RunIoApp> createState() => _RunIoAppState();
}

class _RunIoAppState extends ConsumerState<RunIoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the account in step: new runs upload, profile edits follow.
    final sync = ref.read(cloudSyncProvider);
    ref.listenManual(
      gameProvider.select((g) => g.runs.length),
      (_, _) => sync.pushRuns(),
    );
    ref.listenManual(
      gameProvider.select(
        (g) =>
            (g.user?.color, g.user?.avatar, g.user?.discoverable, g.homeState),
      ),
      (_, _) => sync.profileChanged(),
    );
    ref.listenManual(
      gameProvider.select(
        (g) => (g.settings.weeklyDistanceGoalM, g.settings.weeklyRunsGoal),
      ),
      (_, _) => sync.goalsChanged(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => sync.onLaunch());
  }

  // Runs finished offline go up when the app comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(cloudSyncProvider).pushRuns();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Only matters in 'system' mode, but cheap to always listen.
  @override
  void didChangePlatformBrightness() => setState(() {});

  AppPalette _palette(String mode) => switch (mode) {
    'light' => AppPalette.light,
    'system' =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.light
          ? AppPalette.light
          : AppPalette.dark,
    _ => AppPalette.dark,
  };

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(gameProvider.select((g) => g.settings.themeMode));
    final palette = _palette(mode);
    AppColors.palette = palette;

    if (!Env.hasMapboxToken) return const _MissingToken();
    // The server stopped supporting this version: playing on would break.
    if (ref.watch(updateRequiredProvider).value ?? false) {
      return const _UpdateRequired();
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle(palette),
      // Colours are read from AppColors at build time, so a new key rebuilds
      // every screen when the palette changes. The router keeps its stack.
      child: MaterialApp.router(
        key: ValueKey(palette.brightness),
        title: 'run.io',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(palette),
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}

class _UpdateRequired extends StatelessWidget {
  const _UpdateRequired();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(AppColors.palette),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Time to update.', style: AppText.title(30)),
                const SizedBox(height: AppSpace.md),
                Text(
                  'This version of run.io is too old for the game server. '
                  'Get the latest version to keep your land.',
                  style: AppText.bodyMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown if you forget --dart-define-from-file=env.json.
class _MissingToken extends StatelessWidget {
  const _MissingToken();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(AppColors.palette),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No Mapbox token.\n\nRun with:\n'
              'flutter run --dart-define-from-file=env.json',
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
