import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/api/api_client.dart';
import '../../state/account.dart';
import '../../state/game_controller.dart';
import '../onboarding/onboarding_art.dart';
import 'auth_widgets.dart';

final _sixDigits = RegExp(r'(?<!\d)(\d{6})(?!\d)');

/// "Enter the code we emailed you." Signs you in when it's right.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _code = TextEditingController();
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  int _wait = 60;
  ApiException? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    // Back from the mail app with the code copied: fill it in.
    _lifecycle = AppLifecycleListener(onResume: _pasteFromClipboard);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _wait = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_wait <= 1) t.cancel();
      setState(() => _wait--);
    });
  }

  Future<void> _pasteFromClipboard() async {
    if (_busy || _code.text.length == 6) return;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    final match = text == null ? null : _sixDigits.firstMatch(text);
    if (match == null || !mounted) return;
    _code.text = match.group(1)!;
  }

  Future<void> _submit([String? _]) async {
    if (_code.text.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(accountProvider.notifier)
          .verifyEmail(widget.email, _code.text);
      if (mounted) context.go(kHomePath);
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      _code.clear();
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(accountProvider.notifier).resendCode(widget.email);
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('New code sent')));
      }
    } on ApiException catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(gameProvider.select((g) => g.user));
    return AuthScaffold(
      scene: OnboardingScene.loop,
      color: user == null ? AppColors.accent : Color(user.color),
      title: 'Check your email.',
      subtitle:
          'Enter the 6-digit code we sent to ${widget.email}. It works for '
          '10 minutes.',
      // Wrong-code errors show on the boxes; only others need the banner.
      error: _error?.code == 'invalid_code' ? null : _error,
      action: BusyButton(
        label: 'Verify',
        busy: _busy,
        onPressed: _code.text.length == 6 ? _submit : null,
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: AppSpace.sm),
        child: TextButton(
          onPressed: _wait > 0 || _busy ? null : _resend,
          child: Text(_wait > 0 ? 'Resend code in ${_wait}s' : 'Resend code'),
        ),
      ),
      children: [
        CodeBoxes(
          controller: _code,
          onCompleted: _submit,
          error: _error?.code == 'invalid_code',
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            if (_error?.code == 'invalid_code') ...[
              const Icon(AppIcons.alert, size: 15, color: AppColors.danger),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Text(
                  _error!.message,
                  style: AppText.small.copyWith(color: AppColors.danger),
                ),
              ),
            ] else
              Expanded(
                child: Text(
                  'Copied it in your mail app? It fills in by itself.',
                  style: AppText.small,
                ),
              ),
            TextButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(AppIcons.paste, size: AppSize.iconSm),
              label: const Text('Paste'),
            ),
          ],
        ),
      ],
    );
  }
}
