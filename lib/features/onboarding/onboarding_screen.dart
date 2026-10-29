import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_icons.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/avatars.dart';
import '../../core/regions.dart';
import '../../engine/engine_config.dart';
import '../../engine/name_gen.dart';
import '../../shared/motion/motion.dart';
import '../../shared/widgets/avatar_picker.dart';
import '../../shared/widgets/player_avatar.dart';
import '../../shared/widgets/wordmark.dart';
import '../../state/game_controller.dart';
import 'onboarding_art.dart';

/// One page of the walkthrough: an animated scene, a headline, a sentence,
/// and the few rules that actually matter, stated plainly.
class _Step {
  const _Step(this.scene, this.title, this.body, this.facts);
  final OnboardingScene scene;
  final String title;
  final String body;
  final List<(IconData, String)> facts;
}

final _steps = [
  const _Step(
    OnboardingScene.welcome,
    'Claim your city,\none run at a time.',
    'run.io turns your runs into territory on the real map. The more '
        'ground you loop, the more of your city is yours.',
    [],
  ),
  _Step(
    OnboardingScene.loop,
    'Run a loop.',
    'Your run draws a line as you go. Get back to where you started and '
        'the loop closes.',
    [
      (
        AppIcons.run,
        'Loops need at least ${EngineConfig.minLoopLengthM.round()} m',
      ),
      (
        AppIcons.loop,
        'Finish within ${EngineConfig.closeRadiusM.round()} m of your start, '
            'or cross your own path',
      ),
    ],
  ),
  const _Step(
    OnboardingScene.claim,
    'Own what\'s inside.',
    'Every hex inside your loop becomes yours. Even if someone else '
        'owned it a minute ago.',
    [
      (AppIcons.territory, 'Each hex is about 50 m across'),
      (
        AppIcons.cooldown,
        'Run through your land to keep it. It fades after 14 days.',
      ),
    ],
  ),
  const _Step(
    OnboardingScene.cut,
    'Watch your trail.',
    'Outside your land, your trail is open. If anyone runs across it, '
        'you\'re out, and you lose all of it.',
    [
      (AppIcons.territory, 'Inside your own land you\'re always safe'),
      (AppIcons.cut, 'Cross a rival\'s open trail and they lose everything'),
      (AppIcons.lightning, 'Keep loops tight. Big loops mean big risk.'),
    ],
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  final _names = NameGen(null, kNationalPlaces);
  late final _nameCtrl = TextEditingController(text: _names.next());
  late int _color = AppColors.playerColors.first;
  late String _avatar = presetAvatarId(
    math.Random().nextInt(kAvatarPresets.length),
  );
  bool _discoverable = true;
  int _page = 0;

  int get _setupPage => _steps.length;
  bool get _onSetup => _page == _setupPage;

  @override
  void dispose() {
    _pages.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _go(int page) => _pages.animateToPage(
    page,
    duration: AppMotion.slow,
    curve: AppMotion.curve,
  );

  void _next() {
    HapticFeedback.selectionClick();
    if (!_onSetup) {
      _go(_page + 1);
      return;
    }
    FocusScope.of(context).unfocus();
    final game = ref.read(gameProvider.notifier);
    game.createUser(name: _nameCtrl.text, color: _color, avatar: _avatar);
    if (!_discoverable) game.setDiscoverable(false);
    context.go('/permissions');
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_color);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Top: wordmark, progress, skip.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                AppSpace.md,
                AppSpace.sm,
                0,
              ),
              child: Row(
                children: [
                  const Wordmark(color: AppColors.accent, size: 20),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _onSetup ? 0 : 1,
                    duration: AppMotion.base,
                    child: TextButton(
                      onPressed: _onSetup ? null : () => _go(_setupPage),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.screen,
                vertical: AppSpace.sm,
              ),
              child: _Progress(count: _steps.length + 1, index: _page),
            ),

            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    _StepView(
                      step: _steps[i],
                      color: color,
                      active: i == _page,
                    ),
                  _setup(color),
                ],
              ),
            ),

            // Bottom: back + next.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                AppSpace.sm,
                AppSpace.screen,
                AppSpace.lg,
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.base,
                    transitionBuilder: (child, a) => SizeTransition(
                      sizeFactor: a,
                      axis: Axis.horizontal,
                      child: FadeTransition(opacity: a, child: child),
                    ),
                    child: _page == 0
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(right: AppSpace.md),
                            child: SizedBox(
                              width: AppSize.button,
                              height: AppSize.button,
                              child: OutlinedButton(
                                onPressed: () => _go(_page - 1),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                child: Transform.flip(
                                  flipX: true,
                                  child: const Icon(
                                    AppIcons.forward,
                                    size: AppSize.icon,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: AppSize.button,
                      child: FilledButton(
                        onPressed: _next,
                        child: AnimatedSwitcher(
                          duration: AppMotion.base,
                          child: Text(
                            _onSetup
                                ? 'Start claiming'
                                : _page == 0
                                ? 'Show me how'
                                : 'Next',
                            key: ValueKey(
                              _page == 0
                                  ? 0
                                  : _onSetup
                                  ? 2
                                  : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setup(Color color) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.xl,
        AppSpace.screen,
        AppSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(child: Text('Make it yours.', style: AppText.title(32))),
          const SizedBox(height: AppSpace.sm),
          FadeSlideIn(
            index: 1,
            child: Text(
              'No account needed. You can change all of this later.',
              style: AppText.bodyMuted,
            ),
          ),
          const SizedBox(height: AppSpace.xxl),

          // Avatar
          FadeSlideIn(
            index: 2,
            child: Center(
              child: Semantics(
                button: true,
                label: 'Change avatar',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showAvatarPicker(
                      context,
                      current: _avatar,
                      seed: 'new',
                      color: color,
                    );
                    if (picked != null) setState(() => _avatar = picked);
                  },
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedSwitcher(
                            duration: AppMotion.base,
                            child: PlayerAvatar(
                              key: ValueKey('$_avatar$_color'),
                              avatar: _avatar,
                              seed: 'new',
                              color: color,
                              size: 96,
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.bg,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                AppIcons.camera,
                                size: 16,
                                color: AppColors.onAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text('Your marker on the map', style: AppText.small),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xxl),

          // Name
          FadeSlideIn(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Runner name', style: AppText.label),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: _nameCtrl,
                  maxLength: 24,
                  textCapitalization: TextCapitalization.words,
                  style: AppText.title(18),
                  decoration: InputDecoration(
                    counterText: '',
                    suffixIcon: IconButton(
                      tooltip: 'New random name',
                      icon: const Icon(AppIcons.dice, size: AppSize.icon),
                      color: AppColors.textSecondary,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _nameCtrl.text = _names.next();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),

          // Colour
          FadeSlideIn(
            index: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Territory colour', style: AppText.label),
                const SizedBox(height: AppSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final c in AppColors.playerColors)
                      Semantics(
                        button: true,
                        selected: c == _color,
                        label: 'Territory colour',
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _color = c);
                          },
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c == _color
                                    ? AppColors.text
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(c),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),

          // Privacy
          FadeSlideIn(
            index: 5,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.xs,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                title: const Text('Discoverable'),
                subtitle: Text(
                  _discoverable
                      ? 'Others see your name and stats, and runners nearby '
                            'can find you.'
                      : 'You\'ll show as an anonymous runner. Your land '
                            'still counts.',
                  style: AppText.small,
                ),
                value: _discoverable,
                onChanged: (v) => setState(() => _discoverable = v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented progress: one bar per page, filled up to the current one.
class _Progress extends StatelessWidget {
  const _Progress({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step ${index + 1} of $count',
    excludeSemantics: true,
    child: Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.xs),
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.curve,
              height: 4,
              decoration: BoxDecoration(
                color: i <= index ? AppColors.accent : AppColors.elevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _StepView extends StatelessWidget {
  const _StepView({
    required this.step,
    required this.color,
    required this.active,
  });

  final _Step step;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: math.min(box.maxHeight * 0.45, box.maxWidth),
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: OnboardingArt(
                    scene: step.scene,
                    color: color,
                    active: active,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xxl),
              // Keyed on [active] so the text eases in each time you
              // arrive on the page.
              FadeSlideIn(
                key: ValueKey(active),
                child: Text(step.title, style: AppText.title(30)),
              ),
              const SizedBox(height: AppSpace.md),
              FadeSlideIn(
                key: ValueKey('b$active'),
                index: 1,
                child: Text(
                  step.body,
                  style: AppText.bodyMuted.copyWith(fontSize: 16),
                ),
              ),
              if (step.facts.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                for (var i = 0; i < step.facts.length; i++)
                  FadeSlideIn(
                    key: ValueKey('f$i$active'),
                    index: 2 + i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              step.facts[i].$1,
                              size: 16,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                step.facts[i].$2,
                                style: AppText.body,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpace.lg),
            ],
          ),
        ),
      ),
    );
  }
}
