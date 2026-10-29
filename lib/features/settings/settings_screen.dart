import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/constants.dart';
import '../../core/notifications.dart';
import '../../core/regions.dart';
import '../../engine/track_point.dart';
import '../../state/game_controller.dart';
import '../../state/location_providers.dart';
import '../../state/offline_map.dart';
import '../../app/theme/app_icons.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTaps = 0;

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _onVersionTap() {
    final game = ref.read(gameProvider);
    if (game.settings.debugUnlocked) return;
    _versionTaps++;
    if (_versionTaps >= 5) {
      ref
          .read(gameProvider.notifier)
          .updateSettings((s) => s.copyWith(debugUnlocked: true));
      _toast('Debug tools unlocked');
    }
  }

  Future<void> _wipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Wipe everything?', style: AppText.title(20)),
        content: Text(
          'Your player, territory, rivals and runs will be deleted.',
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
            child: const Text('Wipe'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(gameProvider.notifier).wipe();
    if (mounted) context.go('/onboarding');
  }

  void _reseed() {
    final pos = ref.read(positionProvider);
    final here = switch (pos) {
      AsyncData<TrackPoint>(:final value) => value.pos,
      _ => ref.read(fallbackCenterProvider) ?? kDefaultCenter,
    };
    ref.read(gameProvider.notifier).reseedRivals(here);
    _toast('New rivals seeded around you');
  }

  Future<void> _pickState() async {
    final current = ref.read(gameProvider).homeState;
    final code = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Where do you run?', style: AppText.title(22)),
            ),
            for (final st in kStates)
              ListTile(
                title: Text(st.name),
                trailing: st.code == current
                    ? Icon(AppIcons.check, color: AppColors.text)
                    : null,
                onTap: () => Navigator.pop(ctx, st.code),
              ),
          ],
        ),
      ),
    );
    if (code == null || !mounted) return;
    ref.read(gameProvider.notifier).setHomeState(code);
    _toast('Rivals renamed for ${stateByCode(code)!.name}');
  }

  Future<void> _offlineMap() async {
    final offline = ref.read(offlineMapProvider);
    final ctrl = ref.read(offlineMapProvider.notifier);
    if (offline.status == OfflineStatus.downloading) return;

    if (offline.status == OfflineStatus.ready) {
      final remove = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Offline map', style: AppText.title(20)),
          content: Text(
            'Your area is saved (${_mb(offline.bytes)}). Remove it to free '
            'space, or keep it.',
            style: AppText.bodyMuted,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (remove == true) await ctrl.remove();
      return;
    }

    final pos = ref.read(positionProvider);
    final center = switch (pos) {
      AsyncData<TrackPoint>(:final value) => value.pos,
      _ => ref.read(fallbackCenterProvider),
    };
    if (center == null) {
      _toast('Waiting for GPS. Try again in a moment.');
      return;
    }
    final wifiOnly = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Save your area?', style: AppText.title(20)),
        content: Text(
          'Downloads the map ${(OfflineMapController.radiusM / 1000).round()} '
          'km around you, usually 20 to 60 MB. The map then loads without '
          'data and keeps working on weak signal.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Use mobile data'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Wi-Fi only'),
          ),
        ],
      ),
    );
    if (wifiOnly == null) return;
    await ctrl.download(center, wifiOnly: wifiOnly);
    if (!mounted) return;
    final done = ref.read(offlineMapProvider).status;
    _toast(
      done == OfflineStatus.ready
          ? 'Offline map saved'
          : wifiOnly
          ? 'Couldn\'t download. Connect to Wi-Fi and try again.'
          : 'Couldn\'t download. Check your connection.',
    );
  }

  static String _mb(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

  String _offlineSubtitle(OfflineMapState s) => switch (s.status) {
    OfflineStatus.checking => 'Checking…',
    OfflineStatus.none => 'Save the map around you to use less data',
    OfflineStatus.downloading => 'Downloading… ${(s.progress * 100).round()}%',
    OfflineStatus.ready => 'Saved, ${_mb(s.bytes)}',
    OfflineStatus.failed => 'Download failed. Tap to try again.',
  };

  Future<void> _trackingHelp() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Track with the screen off', style: AppText.title(20)),
        content: Text(
          'Some phones, Samsung especially, stop apps in the background to '
          'save battery, which cuts your run short.\n\n'
          'Open app settings, then Battery, and choose Unrestricted. Also '
          'allow notifications so you can see when a run is being tracked.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            child: const Text('Open app settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gameProvider.select((g) => g.settings));
    final offline = ref.watch(offlineMapProvider);
    final discoverable = ref.watch(
      gameProvider.select((g) => g.user?.discoverable ?? true),
    );
    final homeState = ref.watch(homeStateProvider);
    final game = ref.read(gameProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const _Section('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'dark',
                    icon: Icon(AppIcons.dark),
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: 'light',
                    icon: Icon(AppIcons.light),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: 'system',
                    icon: Icon(AppIcons.auto),
                    label: Text('Auto'),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (v) =>
                    game.updateSettings((s) => s.copyWith(themeMode: v.first)),
              ),
            ),
          ),
          const _Section('Privacy'),
          SwitchListTile(
            secondary: Icon(
              discoverable ? AppIcons.visible : AppIcons.hidden,
              size: AppSize.icon,
            ),
            title: const Text('Discoverable'),
            subtitle: Text(
              discoverable
                  ? 'Others see your name, avatar and stats'
                  : 'You show as an anonymous runner. Your land still '
                        'counts.',
              style: AppText.small,
            ),
            value: discoverable,
            onChanged: (v) => game.setDiscoverable(v),
          ),
          SwitchListTile(
            secondary: const Icon(AppIcons.nearby, size: AppSize.icon),
            title: const Text('Runners nearby'),
            subtitle: Text(
              discoverable
                  ? 'Get a notification when a potential friend is close. '
                        'Never shows where they are.'
                  : 'Only available while you\'re discoverable',
              style: AppText.small,
            ),
            value: discoverable && settings.nearbyAlerts,
            onChanged: discoverable
                ? (v) async {
                    if (v && !await Notifications.requestPermission()) {
                      _toast('Allow notifications for run.io to get these');
                      return;
                    }
                    game.updateSettings((s) => s.copyWith(nearbyAlerts: v));
                  }
                : null,
          ),
          const _Section('Region'),
          ListTile(
            title: const Text('Home state'),
            subtitle: Text(
              homeState?.name ?? 'Set from your first GPS fix',
              style: AppText.small,
            ),
            trailing: const Icon(AppIcons.chevron),
            onTap: _pickState,
          ),
          ListTile(
            title: const Text('Offline map'),
            subtitle: Text(_offlineSubtitle(offline), style: AppText.small),
            trailing: offline.status == OfflineStatus.downloading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      value: offline.progress == 0 ? null : offline.progress,
                    ),
                  )
                : Icon(
                    offline.status == OfflineStatus.ready
                        ? AppIcons.downloaded
                        : AppIcons.download,
                  ),
            onTap: _offlineMap,
          ),
          const _Section('Run'),
          SwitchListTile(
            title: const Text('Auto-pause'),
            subtitle: Text(
              'Stops the clock when you stand still. Your loop stays open.',
              style: AppText.small,
            ),
            value: settings.autoPause,
            onChanged: (v) =>
                game.updateSettings((s) => s.copyWith(autoPause: v)),
          ),
          SwitchListTile(
            title: const Text('Use miles'),
            value: settings.useMiles,
            onChanged: (v) =>
                game.updateSettings((s) => s.copyWith(useMiles: v)),
          ),
          SwitchListTile(
            title: const Text('Haptics'),
            value: settings.haptics,
            onChanged: (v) =>
                game.updateSettings((s) => s.copyWith(haptics: v)),
          ),
          SwitchListTile(
            title: const Text('Keep screen on during runs'),
            value: settings.keepScreenOn,
            onChanged: (v) =>
                game.updateSettings((s) => s.copyWith(keepScreenOn: v)),
          ),
          ListTile(
            title: const Text('Track with the screen off'),
            subtitle: Text(
              'Battery settings that keep runs from cutting out',
              style: AppText.small,
            ),
            trailing: const Icon(AppIcons.chevron),
            onTap: _trackingHelp,
          ),
          ListTile(
            title: const Text('Location permission'),
            trailing: const Icon(AppIcons.chevron),
            onTap: () => context.push('/permissions'),
          ),
          if (settings.debugUnlocked) ...[
            const _Section('Debug'),
            SwitchListTile(
              title: const Text('Sim mode'),
              subtitle: Text(
                'Tap the map to move. Runs at 4x speed.',
                style: AppText.small,
              ),
              value: settings.simMode,
              onChanged: (v) {
                if (!v) ref.read(simSourceProvider).stop();
                game.updateSettings((s) => s.copyWith(simMode: v));
              },
            ),
            ListTile(
              title: const Text('Reseed rivals here'),
              trailing: const Icon(AppIcons.refresh),
              onTap: _reseed,
            ),
            ListTile(
              title: const Text(
                'Wipe all data',
                style: TextStyle(color: AppColors.danger),
              ),
              trailing: const Icon(AppIcons.delete, color: AppColors.danger),
              onTap: _wipe,
            ),
          ],
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: _onVersionTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('run.io v$kAppVersion', style: AppText.small),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      title,
      style: AppText.label.copyWith(color: AppColors.textMuted),
    ),
  );
}
