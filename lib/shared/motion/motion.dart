import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Fades and lifts its child in once, after [index] × a short stagger, so
/// a screen's sections arrive one after another instead of all at once.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: AppMotion.slow);
  late final _a = CurvedAnimation(parent: _c, curve: AppMotion.curve);

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 40 * widget.index.clamp(0, 8));
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(_a),
      child: widget.child,
    ),
  );
}

/// A number that counts to its new value instead of jumping.
class AnimatedValue extends StatelessWidget {
  const AnimatedValue({super.key, required this.value, required this.builder});

  final double value;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value),
    duration: AppMotion.slow,
    curve: AppMotion.curve,
    builder: (context, v, _) => builder(context, v),
  );
}

/// A progress bar that fills smoothly.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({super.key, required this.progress, this.height = 6});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0, 1)),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      builder: (_, v, _) =>
          LinearProgressIndicator(value: v, minHeight: height),
    ),
  );
}

/// The tabs: like an IndexedStack (every tab stays alive, the map
/// included), but the tab you switch to fades in.
class FadingIndexedStack extends StatefulWidget {
  const FadingIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<FadingIndexedStack> createState() => _FadingIndexedStackState();
}

class _FadingIndexedStackState extends State<FadingIndexedStack>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: AppMotion.base,
    value: 1,
  );
  late final _a = CurvedAnimation(parent: _c, curve: AppMotion.curve);

  @override
  void didUpdateWidget(FadingIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: widget.index,
    children: [
      for (var i = 0; i < widget.children.length; i++)
        // Same structure for every child, so switching never rebuilds a
        // tab's state; only the active one gets the animated opacity.
        FadeTransition(
          opacity: i == widget.index ? _a : kAlwaysCompleteAnimation,
          child: TickerMode(
            enabled: i == widget.index,
            child: widget.children[i],
          ),
        ),
    ],
  );
}
