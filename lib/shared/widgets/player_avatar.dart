import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/app_icons.dart';
import '../../core/avatars.dart';
import '../map/avatar_marker.dart' show kAnonymousGrey;

/// Round avatar with a ring in the player's colour. Photos are cropped to
/// fill the circle.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.avatar,
    required this.seed,
    required this.color,
    this.size = 40,
    this.ring = true,
  });

  final String? avatar;

  /// The player id. Picks a stable preset when [avatar] is null.
  final String seed;
  final Color color;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final source = AvatarSource.of(avatar, seed);
    final inner = switch (source) {
      PhotoAvatar(:final file) => Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        gaplessPlayback: true,
      ),
      PresetAvatar(:final preset) => ColoredBox(
        color: color,
        child: Center(
          child: Icon(preset.icon, color: Colors.white, size: size * 0.5),
        ),
      ),
      AnonymousAvatar() => ColoredBox(
        color: kAnonymousGrey,
        child: Center(
          child: Icon(
            AppIcons.anonymous,
            color: Colors.white.withValues(alpha: 0.9),
            size: size * 0.62,
          ),
        ),
      ),
    };
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(
        ring && source is PhotoAvatar ? (size * 0.06).clamp(1.5, 4) : 0,
      ),
      decoration: BoxDecoration(
        color: ring && source is PhotoAvatar ? color : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: ColoredBox(color: AppColors.elevated, child: inner),
      ),
    );
  }
}
