import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'player_avatar.dart';

class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class PlayerChip extends StatelessWidget {
  const PlayerChip({
    super.key,
    required this.name,
    required this.color,
    this.style,
    this.avatar,
    this.seed,
    this.avatarSize = 28,
  });

  final String name;
  final Color color;
  final TextStyle? style;

  /// With a [seed] (the player id) the chip shows their avatar instead
  /// of a colour dot.
  final String? avatar;
  final String? seed;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (seed != null)
          PlayerAvatar(
            avatar: avatar,
            seed: seed!,
            color: color,
            size: avatarSize,
          )
        else
          ColorDot(color: color),
        SizedBox(width: seed != null ? 10 : 8),
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: style ?? AppText.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
