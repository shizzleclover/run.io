import 'package:flutter/material.dart';
import '../../app/theme/app_icons.dart';

/// Post (4:5) or Story (9:16) for the share card.
class CardFormatToggle extends StatelessWidget {
  const CardFormatToggle({
    super.key,
    required this.story,
    required this.onChanged,
  });

  final bool story;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: false,
          icon: Icon(AppIcons.post),
          label: Text('Post'),
        ),
        ButtonSegment(
          value: true,
          icon: Icon(AppIcons.story),
          label: Text('Story'),
        ),
      ],
      selected: {story},
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}
