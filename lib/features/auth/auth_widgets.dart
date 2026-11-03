import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/env.dart';
import '../../shared/motion/motion.dart';
import '../../shared/widgets/wordmark.dart';
import '../onboarding/onboarding_art.dart';

/// The frame every account screen shares: wordmark, a strip of the game's
/// hex art, a big title, the form, and the main button pinned in reach of
/// your thumb.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.action,
    this.scene = OnboardingScene.claim,
    this.color = AppColors.accent,
    this.header,
    this.error,
    this.footer,
    this.showBack = true,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget action;

  /// The little animation at the top, in the runner's colour.
  final OnboardingScene scene;
  final Color color;

  /// Above the title, e.g. the sign-up / sign-in switch.
  final Widget? header;

  /// Shown as a banner over the form.
  final ApiException? error;
  final Widget? footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.screen,
                0,
              ),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    if (showBack && Navigator.of(context).canPop())
                      const BackButton()
                    else
                      const SizedBox(width: AppSpace.md),
                    Wordmark(color: color, size: 20),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screen,
                  AppSpace.md,
                  AppSpace.screen,
                  AppSpace.xl,
                ),
                children: [
                  FadeSlideIn(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Container(
                        height: 132,
                        color: AppColors.surface,
                        child: OnboardingArt(scene: scene, color: color),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  if (header != null) ...[
                    FadeSlideIn(index: 1, child: header!),
                    const SizedBox(height: AppSpace.xl),
                  ],
                  FadeSlideIn(
                    index: 1,
                    child: AnimatedSwitcher(
                      duration: AppMotion.base,
                      child: Column(
                        key: ValueKey(title),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppText.title(30)),
                          const SizedBox(height: AppSpace.sm),
                          Text(subtitle, style: AppText.bodyMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  ErrorBanner(error),
                  for (var i = 0; i < children.length; i++)
                    FadeSlideIn(index: 2 + i, child: children[i]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                AppSpace.sm,
                AppSpace.screen,
                AppSpace.lg,
              ),
              child: Column(
                children: [
                  SizedBox(width: double.infinity, child: action),
                  ?footer,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Create account | Sign in": a pill with a sliding thumb.
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.base,
                curve: AppMotion.curve,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i == index) return;
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: AppMotion.fast,
                              style: AppText.small.copyWith(
                                fontWeight: FontWeight.w600,
                                color: i == index
                                    ? AppColors.text
                                    : AppColors.textSecondary,
                              ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// What a field reports under itself: an error, a good sign, or a hint.
sealed class FieldStatus {
  const FieldStatus(this.text);
  final String text;
}

class FieldError extends FieldStatus {
  const FieldError(super.text);
}

class FieldOk extends FieldStatus {
  const FieldOk(super.text);
}

class FieldHint extends FieldStatus {
  const FieldHint(super.text);
}

/// A labelled field with an icon, and its status underneath.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.status,
    this.trailing,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final FieldStatus? status;
  final Widget? trailing;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final (color, statusIcon) = switch (s) {
      FieldError() => (AppColors.danger, AppIcons.alert),
      FieldOk() => (AppColors.ok, AppIcons.available),
      _ => (AppColors.textMuted, null),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: AppSpace.sm),
          TextField(
            controller: controller,
            autofocus: autofocus,
            obscureText: obscure,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            style: AppText.body,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, size: AppSize.iconSm),
              prefixIconColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              suffixIcon: trailing,
              enabledBorder: s is FieldError
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.danger),
                    )
                  : null,
            ),
          ),
          AnimatedSize(
            duration: AppMotion.fast,
            alignment: Alignment.topLeft,
            child: s == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpace.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (statusIcon != null) ...[
                          Icon(statusIcon, size: 15, color: color),
                          const SizedBox(width: AppSpace.xs),
                        ],
                        Expanded(
                          child: Text(
                            s.text,
                            style: AppText.small.copyWith(color: color),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A password field: [AuthField] with a show/hide eye.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.status,
    this.newPassword = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final FieldStatus? status;

  /// Lets the password manager suggest a strong one.
  final bool newPassword;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    return AuthField(
      controller: widget.controller,
      label: widget.label,
      icon: AppIcons.lock,
      obscure: !_shown,
      status: widget.status,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      trailing: IconButton(
        tooltip: _shown ? 'Hide password' : 'Show password',
        icon: Icon(
          _shown ? AppIcons.hidePassword : AppIcons.showPassword,
          size: AppSize.iconSm,
        ),
        color: AppColors.textSecondary,
        onPressed: () => setState(() => _shown = !_shown),
      ),
    );
  }
}

/// A problem that isn't about one field: no connection, wrong password.
/// Field problems show on their fields instead.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.error, {super.key});

  final ApiException? error;

  @override
  Widget build(BuildContext context) {
    final e = error;
    final show = e != null && e.fields.isEmpty;
    final offline = e?.code == 'offline';
    return AnimatedSize(
      duration: AppMotion.base,
      curve: AppMotion.curve,
      alignment: Alignment.topCenter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xl),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      offline ? AppIcons.offline : AppIcons.alert,
                      size: AppSize.icon,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.message, style: AppText.body),
                          // On staging, say exactly what to check.
                          if (offline && Env.isStaging) ...[
                            const SizedBox(height: AppSpace.sm),
                            Text(
                              'Staging: is `npm run dev` running, and did you '
                              'run `adb reverse tcp:8080 tcp:8080`? '
                              'Trying ${Env.apiUrl}.',
                              style: AppText.small,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The main button, with a spinner while [busy].
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSize.button,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: AnimatedSwitcher(
          duration: AppMotion.fast,
          child: busy
              ? SizedBox.square(
                  key: const ValueKey('busy'),
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textSecondary,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label),
                    const SizedBox(width: AppSpace.sm),
                    const Icon(AppIcons.forward, size: AppSize.iconSm),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Six boxes for an email code. One hidden field does the typing, so
/// paste and the keyboard's code suggestion just work.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.error = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final bool error;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    final code = widget.controller.text;
    if (code.length == 6) widget.onCompleted(code);
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: Stack(
        children: [
          // The real field: invisible, but it owns focus and the keyboard.
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              showCursor: false,
              enableInteractiveSelection: false,
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) SizedBox(width: i == 3 ? AppSpace.lg : AppSpace.sm),
                Expanded(child: _box(code, i)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _box(String code, int i) {
    final filled = i < code.length;
    final active = _focus.hasFocus && i == code.length.clamp(0, 5);
    final border = widget.error
        ? AppColors.danger
        : active
        ? AppColors.accent
        : Colors.transparent;
    return AnimatedContainer(
      duration: AppMotion.fast,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border, width: 1.5),
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        transitionBuilder: (child, a) =>
            ScaleTransition(scale: a, child: child),
        child: Text(
          filled ? code[i] : '',
          key: ValueKey('$i${filled ? code[i] : ''}'),
          style: AppText.number(26),
        ),
      ),
    );
  }
}
