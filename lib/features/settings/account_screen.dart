import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/cards.dart';
import '../../core/api/runio_api.dart';
import '../../shared/widgets/player_chip.dart';
import '../../state/account.dart';

/// Your account: email, password, sessions, your data, and deleting it.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(accountProvider);
    if (session == null) return const Scaffold();
    RunioApi api() => ref.read(runioApiProvider)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ListTile(
            leading: const Icon(AppIcons.account, size: AppSize.icon),
            title: Text(session.username),
            subtitle: Text(session.email, style: AppText.small),
          ),
          const _Section('Sign-in'),
          ListTile(
            leading: const Icon(AppIcons.email, size: AppSize.icon),
            title: const Text('Change email'),
            onTap: () => _changeEmail(context, ref),
          ),
          ListTile(
            leading: const Icon(AppIcons.lock, size: AppSize.icon),
            title: const Text('Change password'),
            subtitle: Text(
              'Signs you out on your other phones',
              style: AppText.small,
            ),
            onTap: () => _changePassword(context, ref),
          ),
          ListTile(
            leading: const Icon(AppIcons.signOut, size: AppSize.icon),
            title: const Text('Sign out everywhere'),
            subtitle: Text(
              'Every phone, including this one',
              style: AppText.small,
            ),
            onTap: () async {
              if (!await _confirm(
                context,
                title: 'Sign out everywhere?',
                body:
                    "Every phone signed in to ${session.username} is signed "
                    "out. This phone's copy is removed; sign back in to get "
                    'it back.',
                action: 'Sign out',
              )) {
                return;
              }
              if (!context.mounted) return;
              await _run(context, () async {
                await api().signOutEverywhere();
                await ref.read(accountProvider.notifier).signOut();
              });
            },
          ),
          const _Section('Privacy'),
          ListTile(
            leading: const Icon(AppIcons.hidden, size: AppSize.icon),
            title: const Text('Blocked runners'),
            trailing: const Icon(AppIcons.chevron),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _BlockedScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(AppIcons.download, size: AppSize.icon),
            title: const Text('Download my data'),
            subtitle: Text(
              'Profile, runs, land and follows, as a file',
              style: AppText.small,
            ),
            onTap: () => _run(context, () async {
              final data = await api().exportData();
              final dir = await getTemporaryDirectory();
              final file = File('${dir.path}/runio-${session.username}.json');
              await file.writeAsString(
                const JsonEncoder.withIndent('  ').convert(data),
              );
              await SharePlus.instance.share(
                ShareParams(files: [XFile(file.path)]),
              );
            }),
          ),
          const _Section('Danger zone'),
          ListTile(
            leading: const Icon(
              AppIcons.delete,
              size: AppSize.icon,
              color: AppColors.danger,
            ),
            title: const Text(
              'Delete account',
              style: TextStyle(color: AppColors.danger),
            ),
            subtitle: Text(
              'Your land goes neutral and your runs are deleted',
              style: AppText.small,
            ),
            onTap: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final values = await _form(
      context,
      title: 'Change password',
      fields: const [
        ('Current password', true),
        ('New password (8+ characters)', true),
        ('Confirm new password', true),
      ],
      action: 'Save',
    );
    if (values == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(runioApiProvider)!
          .changePassword(
            currentPassword: values[0],
            password: values[1],
            confirmPassword: values[2],
          ),
      done: 'Password changed',
    );
  }

  Future<void> _changeEmail(BuildContext context, WidgetRef ref) async {
    final values = await _form(
      context,
      title: 'Change email',
      fields: const [('New email', false), ('Password', true)],
      action: 'Send code',
    );
    if (values == null || !context.mounted) return;
    final api = ref.read(runioApiProvider)!;
    final sent = await _run(
      context,
      () => api.requestEmailChange(values[0].trim(), values[1]),
    );
    if (!sent || !context.mounted) return;
    final code = await _form(
      context,
      title: 'Check your new email',
      body: 'Enter the 6-digit code we sent to ${values[0].trim()}.',
      fields: const [('6-digit code', false)],
      action: 'Confirm',
    );
    if (code == null || !context.mounted) return;
    await _run(context, () async {
      final me = await api.confirmEmailChange(code[0].trim());
      await ref
          .read(accountProvider.notifier)
          .updateEmail(me['email'] as String);
    }, done: 'Email changed');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await _confirm(
      context,
      title: 'Delete your account?',
      body:
          'Your land goes neutral, your runs and follows are deleted, and you '
          'leave your crew. This cannot be undone.',
      action: 'Continue',
    )) {
      return;
    }
    if (!context.mounted) return;
    final password = await _form(
      context,
      title: 'Confirm it\'s you',
      fields: const [('Password', true)],
      action: 'Send code',
    );
    if (password == null || !context.mounted) return;
    final api = ref.read(runioApiProvider)!;
    if (!await _run(context, () => api.requestDeletion(password[0])) ||
        !context.mounted) {
      return;
    }
    final code = await _form(
      context,
      title: 'Last step',
      body: 'Enter the code we emailed you to delete your account for good.',
      fields: const [('6-digit code', false)],
      action: 'Delete forever',
      danger: true,
    );
    if (code == null || !context.mounted) return;
    await _run(context, () async {
      await api.deleteAccount(code[0].trim());
      await ref.read(accountProvider.notifier).forget();
    });
  }
}

/// Runs [action]; shows the server's message if it fails. Returns success.
Future<bool> _run(
  BuildContext context,
  Future<void> Function() action, {
  String? done,
}) async {
  String? message = done;
  var ok = true;
  try {
    await action();
  } on ApiException catch (e) {
    message =
        e.field('password') ??
        e.field('currentPassword') ??
        e.field('newEmail') ??
        e.field('confirmPassword') ??
        e.field('code') ??
        e.message;
    ok = false;
  }
  if (message != null && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
  return ok;
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: AppText.title(20)),
      content: Text(body, style: AppText.bodyMuted),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// A small dialog form. Fields are (label, obscured). Null if cancelled.
Future<List<String>?> _form(
  BuildContext context, {
  required String title,
  String? body,
  required List<(String, bool)> fields,
  required String action,
  bool danger = false,
}) {
  final controllers = [for (final _ in fields) TextEditingController()];
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: AppText.title(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (body != null) ...[
            Text(body, style: AppText.bodyMuted),
            const SizedBox(height: AppSpace.lg),
          ],
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.md),
            TextField(
              controller: controllers[i],
              autofocus: i == 0,
              obscureText: fields[i].$2,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(hintText: fields[i].$1),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, [for (final c in controllers) c.text]),
          style: danger
              ? TextButton.styleFrom(foregroundColor: AppColors.danger)
              : null,
          child: Text(action),
        ),
      ],
    ),
  ).whenComplete(() {
    for (final c in controllers) {
      c.dispose();
    }
  });
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

final _blockedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(runioApiProvider)!.people('blocked'),
);

class _BlockedScreen extends ConsumerWidget {
  const _BlockedScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(_blockedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked runners')),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            e is ApiException ? e.message : 'Something went wrong.',
            style: AppText.bodyMuted,
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  "You haven't blocked anyone.",
                  style: AppText.bodyMuted,
                ),
              )
            : ListView(
                children: [
                  for (final card in list)
                    ListTile(
                      // Blocked runners show anonymous, so show the
                      // card as the server sends it.
                      title: PlayerChip(
                        name: playerFromCard(card).name,
                        color: Color(playerFromCard(card).color),
                        avatar: card['avatar'] as String?,
                        seed: card['id'] as String,
                        avatarSize: 32,
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          await _run(
                            context,
                            () => ref
                                .read(runioApiProvider)!
                                .unblock(card['id'] as String),
                            done: 'Unblocked',
                          );
                          ref.invalidate(_blockedProvider);
                        },
                        child: const Text('Unblock'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
