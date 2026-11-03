import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../core/api/api_client.dart';
import '../../state/account.dart';
import '../../state/game_controller.dart';
import '../onboarding/onboarding_art.dart';
import 'auth_widgets.dart';

final _usernameShape = RegExp(r'^[A-Za-z0-9_]{3,20}$');

/// Create an account, or sign in to one.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.signIn = false});

  final bool signIn;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _signIn = widget.signIn;
  final _email = TextEditingController();
  late final _username = TextEditingController(text: _suggestedUsername());
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _identifier = TextEditingController();
  ApiException? _error;
  bool _busy = false;

  // Live username check.
  Timer? _debounce;
  FieldStatus? _usernameStatus;

  @override
  void initState() {
    super.initState();
    if (_username.text.isNotEmpty) _checkUsername(_username.text);
  }

  /// "Wuse Leopard" from onboarding → "WuseLeopard".
  String _suggestedUsername() {
    final name = ref.read(gameProvider).user?.name ?? '';
    final clean = name.replaceAll(RegExp('[^A-Za-z0-9_]'), '');
    return clean.length > 20 ? clean.substring(0, 20) : clean;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_email, _username, _password, _confirm, _identifier]) {
      c.dispose();
    }
    super.dispose();
  }

  void _checkUsername(String value) {
    _debounce?.cancel();
    final u = value.trim();
    void show(FieldStatus? s) {
      if (mounted) setState(() => _usernameStatus = s);
    }

    if (u.isEmpty) return show(null);
    if (!_usernameShape.hasMatch(u)) {
      return show(
        const FieldHint('3–20 letters, numbers or _. This is what rivals see.'),
      );
    }
    show(const FieldHint('Checking…'));
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final res =
            await ref
                    .read(apiProvider)!
                    .get('/auth/username-available', query: {'u': u})
                as Map<String, dynamic>;
        if (_username.text.trim() != u) return;
        show(
          res['available'] == true
              ? FieldOk('$u is free')
              : const FieldError('That username is taken.'),
        );
      } on ApiException catch (e) {
        if (_username.text.trim() != u) return;
        show(
          e.code == 'offline' ? null : FieldError(e.field('u') ?? e.message),
        );
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = ref.read(accountProvider.notifier);
    try {
      if (_signIn) {
        await account.signIn(_identifier.text.trim(), _password.text);
        if (mounted) context.go(kHomePath);
      } else {
        final email = await account.register(
          email: _email.text.trim(),
          username: _username.text.trim(),
          password: _password.text,
          confirmPassword: _confirm.text,
        );
        if (mounted) {
          context.push('/auth/verify?email=${Uri.encodeQueryComponent(email)}');
        }
      }
    } on ApiException catch (e) {
      if (e.code == 'email_unverified' && mounted) {
        final email = e.extra['email'] as String? ?? '';
        context.push('/auth/verify?email=${Uri.encodeQueryComponent(email)}');
      } else {
        HapticFeedback.heavyImpact();
        setState(() => _error = e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The server's word on a field wins over the live checks.
  FieldStatus? _serverError(String field) {
    final msg = _error?.field(field);
    return msg == null ? null : FieldError(msg);
  }

  FieldStatus? get _passwordStatus {
    final server = _serverError('password');
    if (server != null) return server;
    final n = _password.text.length;
    if (n == 0) return const FieldHint('At least 8 characters.');
    return n >= 8
        ? const FieldOk('Long enough')
        : FieldHint('${8 - n} more character${8 - n == 1 ? '' : 's'}');
  }

  FieldStatus? get _confirmStatus {
    final server = _serverError('confirmPassword');
    if (server != null) return server;
    if (_confirm.text.isEmpty) return null;
    return _confirm.text == _password.text
        ? const FieldOk('Passwords match')
        : const FieldError("Passwords don't match.");
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(gameProvider.select((g) => g.user));
    final color = user == null ? AppColors.accent : Color(user.color);
    return AutofillGroup(
      child: AuthScaffold(
        // Players who already made a runner can't skip having an account.
        showBack: user == null,
        color: color,
        scene: _signIn ? OnboardingScene.welcome : OnboardingScene.claim,
        error: _error,
        header: ModeSwitch(
          labels: const ['Create account', 'Sign in'],
          index: _signIn ? 1 : 0,
          onChanged: (i) => setState(() {
            _signIn = i == 1;
            _error = null;
          }),
        ),
        title: _signIn ? 'Welcome back.' : 'Claim your name.',
        subtitle: _signIn
            ? 'Your land, runs and crew are waiting.'
            : 'Your username is what rivals see on the map. Runs and crew '
                  'are saved to your account.',
        action: BusyButton(
          label: _signIn ? 'Sign in' : 'Create account',
          busy: _busy,
          onPressed: _submit,
        ),
        children: _signIn
            ? [
                AuthField(
                  controller: _identifier,
                  label: 'Email or username',
                  icon: AppIcons.user,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  status: _serverError('identifier'),
                ),
                PasswordField(
                  controller: _password,
                  label: 'Password',
                  status: _serverError('password'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/auth/reset'),
                    child: const Text('Forgot password?'),
                  ),
                ),
              ]
            : [
                AuthField(
                  controller: _email,
                  label: 'Email',
                  icon: AppIcons.email,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  status:
                      _serverError('email') ??
                      const FieldHint("We'll send a code to check it's you."),
                ),
                AuthField(
                  controller: _username,
                  label: 'Username',
                  icon: AppIcons.account,
                  hint: 'AgbowoFalcon',
                  autofillHints: const [AutofillHints.newUsername],
                  status: _serverError('username') ?? _usernameStatus,
                  onChanged: _checkUsername,
                ),
                PasswordField(
                  controller: _password,
                  label: 'Password',
                  newPassword: true,
                  status: _passwordStatus,
                  onChanged: (_) => setState(() {}),
                ),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirm password',
                  newPassword: true,
                  status: _confirmStatus,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ],
      ),
    );
  }
}
