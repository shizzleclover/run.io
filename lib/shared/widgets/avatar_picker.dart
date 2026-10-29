import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../core/avatars.dart';
import 'player_avatar.dart';
import '../../app/theme/app_icons.dart';

/// Bottom sheet: built-in avatars, or a photo from the gallery or camera.
/// Returns the new avatar id, or null if nothing changed.
Future<String?> showAvatarPicker(
  BuildContext context, {
  required String? current,
  required String seed,
  required Color color,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _AvatarSheet(current: current, seed: seed, color: color),
  );
}

class _AvatarSheet extends StatefulWidget {
  const _AvatarSheet({
    required this.current,
    required this.seed,
    required this.color,
  });

  final String? current;
  final String seed;
  final Color color;

  @override
  State<_AvatarSheet> createState() => _AvatarSheetState();
}

class _AvatarSheetState extends State<_AvatarSheet> {
  bool _busy = false;

  Future<void> _photo(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final id = await AvatarStore.pick(source);
      if (id != null && mounted) Navigator.pop(context, id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t open that. Check permissions.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = AvatarSource.of(widget.current, widget.seed);
    final currentPreset = current is PresetAvatar ? current.preset : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your avatar', style: AppText.title(22)),
          const SizedBox(height: 6),
          Text(
            'It\'s your marker on the map. Everyone sees it.',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _photo(ImageSource.gallery),
                  icon: const Icon(AppIcons.gallery, size: 18),
                  label: const Text('Gallery', maxLines: 1),
                  style: _buttonStyle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _photo(ImageSource.camera),
                  icon: const Icon(AppIcons.camera, size: 18),
                  label: const Text('Camera', maxLines: 1),
                  style: _buttonStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Or pick one', style: AppText.label),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kAvatarPresets.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 72,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (_, i) {
              final selected = identical(kAvatarPresets[i], currentPreset);
              return Semantics(
                button: true,
                selected: selected,
                label: 'Avatar ${i + 1}',
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, presetAvatarId(i)),
                  child: PlayerAvatar(
                    avatar: presetAvatarId(i),
                    seed: widget.seed,
                    color: selected ? widget.color : AppColors.border,
                    ring: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  ButtonStyle get _buttonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.text,
    side: BorderSide(color: AppColors.border),
    padding: const EdgeInsets.symmetric(vertical: 14),
  );
}
