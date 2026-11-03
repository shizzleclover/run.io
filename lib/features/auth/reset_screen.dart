import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_icons.dart';
import '../../core/api/api_client.dart';
import '../../state/account.dart';
import '../onboarding/onboarding_art.dart';
import 'auth_widgets.dart';

/// Forgot password: email → code → new password. Signs you in at the end.
class ResetScreen extends ConsumerStatefulWidget {
  const ResetScreen({super.key});

  @override
  ConsumerState<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends ConsumerState<ResetScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = ref.read(accountProvider.notifier);
    try {
      if (!_sent) {
        await account.forgotPassword(_email.text.trim());
        setState(() => _sent = true);
      } else {
        await account.resetPassword(
          email: _email.text.trim(),
          code: _code.text.trim(),
          password: _password.text,
          confirmPassword: _confirm.text,
        );
        if (mounted) context.go(kHomePath);
      }
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  FieldStatus? _serverError(String field) {
    final msg = _error?.field(field);
    return msg == null ? null : FieldError(msg);
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: AuthScaffold(
        scene: OnboardingScene.cut,
        error: _error,
        title: _sent ? 'Set a new password.' : 'Reset your password.',
        subtitle: _sent
            ? 'If ${_email.text.trim()} has an account, a code is on its way. '
                  'Saving signs you out on every other phone.'
            : "Enter your account's email and we'll send you a code.",
        action: BusyButton(
          label: _sent ? 'Save password' : 'Send code',
          busy: _busy,
          onPressed: _submit,
        ),
        children: _sent
            ? [
                CodeBoxes(
                  controller: _code,
                  onCompleted: (_) {},
                  error: _error?.code == 'invalid_code',
                ),
                const SizedBox(height: 20),
                PasswordField(
                  controller: _password,
                  label: 'New password',
                  newPassword: true,
                  status: _serverError('password'),
                ),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  newPassword: true,
                  status: _serverError('confirmPassword'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
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
                  autofocus: true,
                  status: _serverError('email'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ],
      ),
    );
  }
}
