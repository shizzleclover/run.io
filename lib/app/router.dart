import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/map/map_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/permissions/permissions_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/run_detail_screen.dart';
import '../features/settings/settings_screen.dart';
import '../state/game_controller.dart';
import '../shared/motion/motion.dart';
import 'shell.dart';

/// Tabs, in bottom bar order.
const kHomePath = '/home';
const kMapPath = '/map';
const kLeaderboardPath = '/leaderboard';
const kProfilePath = '/profile';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: kHomePath,
    redirect: (context, state) {
      final game = ref.read(gameProvider);
      final loc = state.matchedLocation;
      if (game.user == null) return loc == '/onboarding' ? null : '/onboarding';
      if (!game.permissionsDone && loc != '/permissions') return '/permissions';
      if (loc == '/onboarding' || loc == '/') return kHomePath;
      return null;
    },
    routes: [
      // Each tab keeps its own stack and scroll position, and the map
      // stays alive while you look at other tabs.
      StatefulShellRoute(
        builder: (_, _, shell) => AppShell(shell: shell),
        navigatorContainerBuilder: (_, shell, children) =>
            FadingIndexedStack(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: kHomePath, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: kMapPath, builder: (_, _) => const MapScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kLeaderboardPath,
                builder: (_, _) => const LeaderboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kProfilePath,
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'run/:id',
                    builder: (_, state) =>
                        RunDetailScreen(runId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full screen, no bottom bar.
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/permissions',
        builder: (_, _) => const PermissionsScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
});
