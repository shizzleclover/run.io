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

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _blocked = false;
  bool _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _blocked = true);
        return;
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                    if (_blocked) ...[
                      const SizedBox(height: AppSpace.xl),
                      Container(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          'Location is blocked for run.io. Open settings, '
                          'allow it, then come back.',
                          style: AppText.body,
                        ),
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: AppSpace.xl),
                    SizedBox(
                      width: double.infinity,
                      height: AppSize.button,
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : _blocked
                            ? Geolocator.openAppSettings
                            : _request,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.onAccent,
                                ),
                              )
                            : Text(_blocked ? 'Open settings' : 'Continue'),
                      ),
                    ),
                    if (_blocked)
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => _blocked = false),
                          child: const Text('I\'ve allowed it, try again'),
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
