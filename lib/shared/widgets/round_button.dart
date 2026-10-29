import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';

/// The big glowing circular button (Start, Pause, Stop).
class RoundButton extends StatefulWidget {
  const RoundButton({
    super.key,
    required this.size,
    required this.color,
    this.icon,
    this.label,
    this.onTap,
    this.onLongPress,
    this.glow = true,
    this.foreground,
    this.semanticLabel,
  });

  final double size;
  final Color color;
  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool glow;
  final Color? foreground;

  /// For screen readers. Defaults to [label].
  final String? semanticLabel;

  @override
  State<RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<RoundButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null || widget.onLongPress != null,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: widget.glow
                  ? [
                      // A soft drop shadow for lift, not a coloured glow.
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: widget.label != null
                  ? Text(
                      widget.label!,
                      style: AppText.title(
                        widget.size * 0.2,
                        color: widget.foreground ?? AppColors.onAccent,
                      ),
                    )
                  : Icon(
                      widget.icon,
                      color: widget.foreground ?? AppColors.onAccent,
                      size: widget.size * 0.42,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
