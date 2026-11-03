import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/auth/reset_screen.dart';
import '../features/auth/verify_screen.dart';
import '../features/crew/crew_screen.dart';
import '../features/home/home_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/map/map_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/permissions/permissions_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/run_detail_screen.dart';
import '../features/settings/account_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/social/inbox_screen.dart';
import '../features/social/people_screen.dart';
import '../state/account.dart';
import '../state/game_controller.dart';
import '../shared/motion/motion.dart';
import 'shell.dart';

/// Tabs, in bottom bar order.
const kHomePath = '/home';
const kMapPath = '/map';
const kLeaderboardPath = '/leaderboard';
const kProfilePath = '/profile';

final routerProvider = Provider<GoRouter>((ref) {
  // Signing in or out (or the server ending the session) re-runs redirect.
  final refresh = ValueNotifier(0);
  ref.listen(accountProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: kHomePath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final game = ref.read(gameProvider);
      final signedIn = ref.read(accountProvider) != null;
      final loc = state.matchedLocation;
      final onAuth = loc.startsWith('/auth');
      if (accountsEnabled && !signedIn) {
        if (onAuth) return null;
        // New players set up their runner first, then make the account.
        if (game.user == null)
          return loc == '/onboarding' ? null : '/onboarding';
        return '/auth';
      }
      if (game.user == null) return loc == '/onboarding' ? null : '/onboarding';
      if (onAuth) return kHomePath;
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
      GoRoute(path: '/crew', builder: (_, _) => const CrewScreen()),
      GoRoute(path: '/inbox', builder: (_, _) => const InboxScreen()),
      GoRoute(path: '/people', builder: (_, _) => const PeopleScreen()),
      GoRoute(
        path: '/settings/account',
        builder: (_, _) => const AccountScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, state) =>
            AuthScreen(signIn: state.uri.queryParameters['mode'] == 'signin'),
        routes: [
          GoRoute(
            path: 'verify',
            builder: (_, state) =>
                VerifyScreen(email: state.uri.queryParameters['email'] ?? ''),
          ),
          GoRoute(path: 'reset', builder: (_, _) => const ResetScreen()),
        ],
      ),
    ],
  );
});
