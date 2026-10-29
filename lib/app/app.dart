import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env.dart';
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
