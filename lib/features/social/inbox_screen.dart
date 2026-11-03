import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/cards.dart';
import '../../shared/widgets/player_avatar.dart';
import '../../shared/widgets/player_sheet.dart';
import '../../state/account.dart';
import '../../state/game_controller.dart';

/// Unread events, for the dot on Home's bell. Refreshed when the inbox
/// closes and when the app comes back.
final unreadProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ref.watch(runioApiProvider);
  if (api == null || !ref.watch(serverModeProvider)) return 0;
  try {
    return await api.unreadCount();
  } on ApiException {
    return 0;
  }
});

final _eventsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.read(runioApiProvider)!;
  final res = await api.events();
  final items = (res['items'] as List).cast<Map<String, dynamic>>();
  // So tapping a name opens their card.
  ref.read(gameProvider.notifier).upsertPlayers([
    for (final e in items)
      if (e['actor'] case final Map<String, dynamic> actor)
        playerFromCard(actor),
  ]);
  await api.markRead();
  ref.invalidate(unreadProvider);
  return items;
});

/// What happened while you weren't looking: land taken, cuts, follows,
/// crew news.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(_eventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_eventsProvider.future),
        child: events.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              _Empty(e is ApiException ? e.message : 'Something went wrong.'),
          data: (items) => items.isEmpty
              ? const _Empty(
                  'Nothing yet. Claims, cuts and new followers show up here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, i) => _EventRow(event: items[i]),
                ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final actor = event['actor'] as Map<String, dynamic>?;
    final player = actor == null ? null : playerFromCard(actor);
    final data = event['data'] as Map<String, dynamic>? ?? const {};
    final who = player?.name ?? 'Someone';
    final n = data['cells'];
    final text = switch (event['type']) {
      'land_taken' => '$who took $n of your hexes. Take them back.',
      'cut' => '$who cut your trail. You lost $n hexes.',
      'you_cut' => "You cut $who's trail. They lost $n hexes.",
      'new_follower' => '$who started following you.',
      'crew_joined' => '$who joined ${data['crew'] ?? 'your crew'}.',
      'crew_member_cut' => 'Your crewmate $who was cut.',
      'referral_joined' => '$who, who you invited, went on their first run.',
      'decayed' => '$n of your hexes faded. Run through your land to keep it.',
      'friend_nearby' => '$who was running near you.',
      _ => 'Something happened.',
    };
    final read = event['read'] == true;
    final when = DateTime.parse(event['createdAt'] as String).toLocal();
    return ListTile(
      onTap: player == null ? null : () => showPlayerSheet(context, player.id),
      leading: player == null
          ? CircleAvatar(
              backgroundColor: AppColors.elevated,
              child: Icon(AppIcons.territory, color: AppColors.textSecondary),
            )
          : PlayerAvatar(
              avatar: player.shownAvatar,
              seed: player.id,
              color: Color(player.color),
            ),
      title: Text(
        text,
        style: AppText.body.copyWith(
          fontWeight: read ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: Text(_ago(when), style: AppText.small),
      trailing: read
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} d ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  // A list, so pull-to-refresh still works when there's nothing.
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Text(
          text,
          style: AppText.bodyMuted,
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}
