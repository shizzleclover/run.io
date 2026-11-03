import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/notifications.dart';
import '../../shared/motion/motion.dart';
import '../../state/game_controller.dart';
import '../../state/location_providers.dart';
import '../../app/theme/app_icons.dart';

/// Explain first, then ask. Both stores reject vague location prompts.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

/// Why we're still on this screen after the user tapped Continue.
enum _Issue {
  none,

  /// Location services (GPS) are switched off for the whole phone.
  gpsOff,

  /// "Don't allow" once. Android lets us ask one more time.
  denied,

  /// Denied twice, or "don't ask again": only Settings can fix it.
  blocked,
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  _Issue _issue = _Issue.none;
  bool _busy = false;

  // Coming back from Settings: pick up whatever the user changed there,
  // so they don't have to find the right button again.
  late final _lifecycle = AppLifecycleListener(onResume: _recheck);

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _recheck() async {
    if (_issue == _Issue.none || _busy) return;
    if (!await Geolocator.isLocationServiceEnabled()) return;
    final perm = await Geolocator.checkPermission();
    if (_granted(perm)) {
      await _finish();
    } else if (_issue == _Issue.gpsOff) {
      // GPS is on now; carry on to the permission prompt.
      await _request();
    }
  }

  static bool _granted(LocationPermission p) =>
      p == LocationPermission.whileInUse || p == LocationPermission.always;

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _issue = _Issue.gpsOff);
        await Geolocator.openLocationSettings();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (_granted(perm)) {
        await _finish();
        return;
      }
      if (!mounted) return;
      setState(
        () => _issue = perm == LocationPermission.deniedForever
            ? _Issue.blocked
            : _Issue.denied,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    ref.read(gameProvider.notifier).completePermissions();
    // Run tracking and nearby runners both notify; ask once, here.
    await Notifications.requestPermission();
    // Restart the location stream now that we're allowed.
    ref.invalidate(locationSourceProvider);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  (String, Color)? get _notice => switch (_issue) {
    _Issue.none => null,
    _Issue.gpsOff => (
      'Location is switched off on this phone. Turn it on, then come '
          'back here.',
      AppColors.warning,
    ),
    _Issue.denied => (
      'run.io can\'t work without location: it\'s how your runs become '
          'territory. Tap Try again and choose "While using the app".',
      AppColors.warning,
    ),
    _Issue.blocked => (
      'Location is blocked. In Settings, open Permissions → Location and '
          'pick "While using the app". We\'ll notice when you\'re back.',
      AppColors.danger,
    ),
  };

  String get _buttonLabel => switch (_issue) {
    _Issue.none => 'Continue',
    _Issue.gpsOff => 'Turn on location',
    _Issue.denied => 'Try again',
    _Issue.blocked => 'Open settings',
  };

  VoidCallback? get _onPressed {
    if (_busy) return null;
    if (_issue == _Issue.blocked) return Geolocator.openAppSettings;
    return _request;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        // Scrolls only when it has to (small screen, large system font).
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screen,
              0,
              AppSpace.screen,
              AppSpace.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: box.maxHeight - AppSpace.lg,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpace.lg),
                    FadeSlideIn(
                      child: Text(
                        'Two quick\npermissions.',
                        style: AppText.title(32),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    FadeSlideIn(
                      index: 1,
                      child: Text(
                        'Here\'s what each one is for. Nothing leaves your '
                        'phone yet: there\'s no server.',
                        style: AppText.bodyMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxl),
                    const FadeSlideIn(
                      index: 2,
                      child: _Reason(
                        icon: AppIcons.location,
                        title: 'Location',
                        body:
                            'Draws your runs on the real map and works out '
                            'which hexes you claim. During a run it keeps '
                            'tracking with the screen off.',
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    const FadeSlideIn(
                      index: 3,
                      child: _Reason(
                        icon: AppIcons.nearby,
                        title: 'Notifications',
                        body:
                            'Shows that a run is being tracked, and tells '
                            'you when a potential friend is nearby. Never '
                            'where they are.',
                      ),
                    ),
                    if (_notice case (final text, final color))
                      FadeSlideIn(
                        key: ValueKey(_issue),
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpace.xl),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpace.lg),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(text, style: AppText.body),
                          ),
                        ),
                      ),
                    const Spacer(),
                    const SizedBox(height: AppSpace.xl),
                    SizedBox(
                      width: double.infinity,
                      height: AppSize.button,
                      child: FilledButton(
                        onPressed: _onPressed,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.onAccent,
                                ),
                              )
                            : Text(_buttonLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: AppSize.icon, color: AppColors.accent),
      ),
      const SizedBox(width: AppSpace.lg),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(body, style: AppText.small),
          ],
        ),
      ),
    ],
  );
}
