import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/cards.dart';
import '../../core/models.dart';
import '../../shared/widgets/player_chip.dart';
import '../../shared/widgets/player_sheet.dart';
import '../../state/account.dart';
import '../../state/cloud_sync.dart';
import '../../state/game_controller.dart';

final _listProvider = FutureProvider.autoDispose.family<List<Player>, String>((
  ref,
  list,
) async {
  final cards = await ref.read(runioApiProvider)!.people(list);
  final players = [for (final c in cards) playerFromCard(c)];
  ref.read(gameProvider.notifier).upsertPlayers(players);
  return players;
});

/// Find runners by name, and see who you follow, who follows you, and
/// your friends (both ways).
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Player>? _results;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = null;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final cards = await ref.read(runioApiProvider)!.search(q.trim());
        final players = [for (final c in cards) playerFromCard(c)];
        ref.read(gameProvider.notifier).upsertPlayers(players);
        if (mounted) setState(() => _results = players);
      } on ApiException catch (e) {
        if (mounted) setState(() => _error = e.message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Runners'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(112),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.screen,
                    0,
                    AppSpace.screen,
                    AppSpace.sm,
                  ),
                  child: TextField(
                    controller: _query,
                    onChanged: _search,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Search by username',
                      prefixIcon: Icon(AppIcons.search, size: AppSize.iconSm),
                    ),
                  ),
                ),
                if (_results == null)
                  const TabBar(
                    tabs: [
                      Tab(text: 'Following'),
                      Tab(text: 'Followers'),
                      Tab(text: 'Friends'),
                    ],
                  ),
              ],
            ),
          ),
        ),
        body: _results != null || _error != null
            ? _PlayerList(
                players: _results ?? const [],
                empty:
                    _error ??
                    'Nobody by that name. Private runners '
                        "don't show up in search.",
              )
            : const TabBarView(
                children: [
                  _Tab('following', "You don't follow anyone yet."),
                  _Tab('followers', 'Nobody follows you yet.'),
                  _Tab(
                    'friends',
                    'Friends are runners you follow who follow you back.',
                  ),
                ],
              ),
      ),
    );
  }
}

class _Tab extends ConsumerWidget {
  const _Tab(this.list, this.empty);
  final String list;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_listProvider(list))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _PlayerList(
            players: const [],
            empty: e is ApiException ? e.message : 'Something went wrong.',
          ),
          data: (players) => _PlayerList(players: players, empty: empty),
        );
  }
}

class _PlayerList extends ConsumerWidget {
  const _PlayerList({required this.players, required this.empty});
  final List<Player> players;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (players.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Text(
          empty,
          style: AppText.bodyMuted,
          textAlign: TextAlign.center,
        ),
      );
    }
    final following = ref.watch(gameProvider.select((g) => g.following));
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      children: [
        for (final p in players)
          ListTile(
            onTap: () => showPlayerSheet(context, p.id),
            title: PlayerChip(
              name: p.shownName,
              color: Color(p.color),
              avatar: p.shownAvatar,
              seed: p.id,
              avatarSize: 36,
            ),
            trailing: p.isPublic
                ? TextButton(
                    onPressed: () =>
                        ref.read(cloudSyncProvider).toggleFollow(p.id),
                    child: Text(
                      following.contains(p.id) ? 'Following' : 'Follow',
                    ),
                  )
                : null,
          ),
      ],
    );
  }
}
