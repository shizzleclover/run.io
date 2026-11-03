import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/format.dart';
import '../../core/invite.dart';
import '../../shared/motion/motion.dart';
import '../../shared/widgets/player_chip.dart';
import '../../shared/widgets/stat_block.dart';
import '../../state/area.dart';
import '../../core/api/api_client.dart';
import '../../state/account.dart';
import '../../state/cloud_sync.dart';
import '../../state/game_controller.dart';
import '../leaderboard/leaderboard_screen.dart';

/// Your crew, or how to start or join one.
class CrewScreen extends ConsumerWidget {
  const CrewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCrew = ref.watch(gameProvider.select((g) => g.myCrew != null));
    return Scaffold(
      appBar: AppBar(title: const Text('Crew')),
      body: AnimatedSwitcher(
        duration: AppMotion.base,
        child: inCrew
            ? const _MyCrew(key: ValueKey('mine'))
            : const _NoCrew(key: ValueKey('none')),
      ),
    );
  }
}

class _NoCrew extends ConsumerStatefulWidget {
  const _NoCrew({super.key});

  @override
  ConsumerState<_NoCrew> createState() => _NoCrewState();
}

class _NoCrewState extends ConsumerState<_NoCrew> {
  final _name = TextEditingController();
  final _invite = TextEditingController();
  String? _joinError;
  String? _createError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref.read(cloudSyncProvider).createCrew(name);
    } on ApiException catch (e) {
      setState(() => _createError = e.field('name') ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final parsed = parseCrewInvite(_invite.text);
    if (parsed == null) {
      setState(
        () => _joinError = 'No crew code in that. It looks like K7QD-9XRM.',
      );
      return;
    }
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      // Signed in: show which crew it is before joining.
      final api = ref.read(runioApiProvider);
      if (api != null && ref.read(accountProvider) != null) {
        final preview = await api.crewPreview(parsed.code);
        if (!mounted || !await _confirmJoin(preview)) return;
      }
      await ref
          .read(cloudSyncProvider)
          .joinCrew(code: parsed.code, name: parsed.name);
    } on ApiException catch (e) {
      setState(() => _joinError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmJoin(Map<String, dynamic> crew) async {
    final area = Fmt.area((crew['areaM2'] as num).toDouble());
    final members = crew['members'] as int;
    final full = crew['full'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(crew['name'] as String, style: AppText.title(20)),
        content: Text(
          full
              ? 'This crew is full.'
              : '$members runner${members == 1 ? '' : 's'} · ${area.value} '
                    '${area.unit} of land. Joining leaves any crew you\'re in.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          if (!full)
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Join'),
            ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text case final text?) {
      _invite.text = text;
      setState(() => _joinError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.sm,
        AppSpace.screen,
        AppSpace.xxl,
      ),
      children: [
        FadeSlideIn(child: Text('Run together.', style: AppText.title(28))),
        const SizedBox(height: AppSpace.sm),
        FadeSlideIn(
          index: 1,
          child: Text(
            'A crew is your running club or your friends. Everyone\'s land '
            'adds up, and crews take each other on for the area.',
            style: AppText.bodyMuted,
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
        FadeSlideIn(
          index: 2,
          child: Text('Start a crew', style: AppText.section),
        ),
        const SizedBox(height: AppSpace.md),
        FadeSlideIn(
          index: 2,
          child: TextField(
            controller: _name,
            maxLength: 32,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _create(),
            onChanged: (_) => setState(() => _createError = null),
            decoration: InputDecoration(
              hintText: 'Crew name',
              counterText: '',
              errorText: _createError,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        FadeSlideIn(
          index: 2,
          child: SizedBox(
            height: AppSize.button,
            child: FilledButton.icon(
              onPressed: _name.text.trim().isEmpty || _busy ? null : _create,
              icon: const Icon(AppIcons.add, size: AppSize.iconSm),
              label: const Text('Create crew'),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.section),
        FadeSlideIn(
          index: 3,
          child: Text('Join a crew', style: AppText.section),
        ),
        const SizedBox(height: AppSpace.xs),
        FadeSlideIn(
          index: 3,
          child: Text(
            'Paste the invite someone sent you, or type their crew code.',
            style: AppText.small,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        FadeSlideIn(
          index: 3,
          child: TextField(
            controller: _invite,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() => _joinError = null),
            decoration: InputDecoration(
              hintText: 'Invite or code',
              errorText: _joinError,
              suffixIcon: IconButton(
                tooltip: 'Paste',
                icon: const Icon(AppIcons.copy),
                onPressed: _paste,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        FadeSlideIn(
          index: 3,
          child: SizedBox(
            height: AppSize.button,
            child: OutlinedButton.icon(
              onPressed: _invite.text.trim().isEmpty || _busy ? null : _join,
              icon: const Icon(AppIcons.join, size: AppSize.iconSm),
              label: const Text('Join crew'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyCrew extends ConsumerWidget {
  const _MyCrew({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, String now) async {
    final ctrl = TextEditingController(text: now);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crew name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 32,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await _run(
      context,
      () => ref.read(cloudSyncProvider).renameCrew(name.trim()),
    );
  }

  Future<void> _newCode(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New crew code?', style: AppText.title(20)),
        content: Text(
          'Invites with the old code stop working. Everyone already in the '
          'crew stays.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('New code'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, () async {
      final crew = await ref.read(runioApiProvider)!.rotateCrewCode();
      ref
          .read(gameProvider.notifier)
          .joinCrew(code: crew['code'] as String, name: crew['name'] as String);
      ref.invalidate(remoteCrewProvider);
    });
  }

  /// Runs a crew action; shows the server's reason if it says no.
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave crew?'),
        content: const Text(
          'Your land stays yours. You can rejoin with the code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(context, () => ref.read(cloudSyncProvider).leaveCrew());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final crew = game.myCrew;
    final user = game.user;
    if (crew == null || user == null) return const SizedBox.shrink();
    final board = ref.watch(crewBoardProvider);
    final session = ref.watch(accountProvider);
    final remoteAsync = ref.watch(remoteCrewProvider);
    final remote = remoteAsync.value;
    final membersNote = session == null
        ? 'Crewmates show up here once you sign in. Everyone who joins with '
              'this code is in the same crew.'
        : remoteAsync.hasError
        ? "Couldn't load your crewmates. Check your connection."
        : null;
    final rank = board.indexWhere((e) => e.crew.code == crew.code) + 1;
    final entry = rank > 0 ? board[rank - 1] : null;
    final area = Fmt.area(entry?.areaM2 ?? 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.sm,
        AppSpace.screen,
        AppSpace.xxl,
      ),
      children: [
        FadeSlideIn(
          child: Row(
            children: [
              if (entry != null) CrewMark(entry: entry, size: 56),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Text(
                  crew.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(24),
                ),
              ),
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(AppIcons.edit),
                color: AppColors.textSecondary,
                onPressed: () => _rename(context, ref, crew.name),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
        FadeSlideIn(
          index: 1,
          child: Row(
            children: [
              Expanded(
                child: StatBlock(
                  value: area.value,
                  unit: area.unit,
                  label: 'Crew land',
                  size: 22,
                ),
              ),
              Expanded(
                child: StatBlock(
                  value: rank == 0 ? '–' : '#$rank',
                  label: 'Among crews',
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
        FadeSlideIn(
          index: 2,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Crew code', style: AppText.small),
                const SizedBox(height: AppSpace.xs),
                Row(
                  children: [
                    Expanded(child: Text(crew.code, style: AppText.number(28))),
                    if (remote?['isOwner'] == true)
                      IconButton(
                        tooltip: 'New code (old invites stop working)',
                        icon: const Icon(AppIcons.refresh),
                        onPressed: () => _newCode(context, ref),
                      ),
                    IconButton(
                      tooltip: 'Copy code',
                      icon: const Icon(AppIcons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: crew.code));
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(content: Text('Code copied')),
                          );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                SizedBox(
                  height: AppSize.button,
                  child: FilledButton.icon(
                    onPressed: () => shareText(crewInvite(crew)),
                    icon: const Icon(AppIcons.invite, size: AppSize.iconSm),
                    label: const Text('Invite to crew'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.section),
        FadeSlideIn(index: 3, child: Text('Members', style: AppText.section)),
        const SizedBox(height: AppSpace.md),
        if (remote case final crew?)
          for (final m in crew['members'] as List)
            FadeSlideIn(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: _Member(
                  member: m as Map<String, dynamic>,
                  me: session!.userId,
                  iOwn: crew['isOwner'] == true,
                ),
              ),
            )
        else ...[
          FadeSlideIn(
            index: 3,
            child: PlayerChip(
              name: '${user.name} (you)',
              color: Color(user.color),
              avatar: user.avatar,
              seed: user.id,
              avatarSize: 36,
            ),
          ),
          if (membersNote != null) ...[
            const SizedBox(height: AppSpace.md),
            FadeSlideIn(
              index: 3,
              child: Text(membersNote, style: AppText.small),
            ),
          ],
        ],
        const SizedBox(height: AppSpace.section),
        Center(
          child: TextButton(
            onPressed: () => _leave(context, ref),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Leave crew'),
          ),
        ),
      ],
    );
  }
}

/// A crewmate from the server: avatar, name, land, owner badge.
class _Member extends ConsumerWidget {
  const _Member({required this.member, required this.me, required this.iOwn});

  final Map<String, dynamic> member;
  final String me;

  /// You own the crew: you can hand it over or remove people.
  final bool iOwn;

  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final player = member['player'] as Map<String, dynamic>;
    final id = player['id'] as String;
    final name = player['name'] as String;
    final api = ref.read(runioApiProvider)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          action == 'owner' ? 'Make $name the owner?' : 'Remove $name?',
          style: AppText.title(20),
        ),
        content: Text(
          action == 'owner'
              ? 'They can rename the crew, change its code and remove people. '
                    'You stay in the crew.'
              : 'Their land stops counting for the crew. They can rejoin with '
                    'the code unless you change it.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action == 'owner' ? 'Make owner' : 'Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (action == 'owner') {
        await api.transferCrew(id);
      } else {
        await api.removeCrewMember(id);
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    ref.invalidate(remoteCrewProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = member['player'] as Map<String, dynamic>;
    final isMe = player['id'] == me;
    final rgb = player['color'] as int?;
    final cells = member['cells'] as int;
    return Row(
      children: [
        Expanded(
          child: PlayerChip(
            name: '${player['name']}${isMe ? ' (you)' : ''}',
            color: rgb == null ? AppColors.accent : Color(fromRgb(rgb)),
            avatar: player['avatar'] as String?,
            seed: player['id'] as String,
            avatarSize: 36,
          ),
        ),
        if (member['isOwner'] == true) ...[
          Text('Owner', style: AppText.small),
          const SizedBox(width: AppSpace.md),
        ],
        Text('$cells hexes', style: AppText.small),
        if (iOwn && !isMe)
          PopupMenuButton<String>(
            tooltip: 'Manage',
            icon: Icon(
              AppIcons.edit,
              size: AppSize.iconSm,
              color: AppColors.textSecondary,
            ),
            onSelected: (a) => _manage(context, ref, a),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'owner', child: Text('Make owner')),
              PopupMenuItem(value: 'remove', child: Text('Remove from crew')),
            ],
          ),
      ],
    );
  }
}
