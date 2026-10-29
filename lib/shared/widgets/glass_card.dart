import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';

/// A solid card that floats over the map. No blur and no outline: a near-
/// opaque surface and a soft shadow keep it readable on any map style.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Only for status (a warning, a toast in a player's colour).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppColors.isDark ? 0.35 : 0.08,
            ),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Round floating icon button for the map edge.
class MapIconButton extends StatelessWidget {
  const MapIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.size = AppSize.mapButton,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Read out by screen readers and shown on long press.
  final String label;
  final double size;

  /// Highlighted, for toggles that are on.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: active ? true : null,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: GlassCard(
              padding: EdgeInsets.zero,
              radius: size / 2,
              child: Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: active ? AppColors.accent : AppColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
