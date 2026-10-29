import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/theme/app_icons.dart';

/// A built-in avatar: a white icon on the player's own colour, so it always
/// matches their territory.
class AvatarPreset {
  const AvatarPreset(this.icon);
  final IconData icon;
}

final kAvatarPresets = [for (final i in AppIcons.avatars) AvatarPreset(i)];

String presetAvatarId(int index) => 'p:$index';

/// A player's avatar resolved to something drawable.
sealed class AvatarSource {
  const AvatarSource();

  /// Parses a stored avatar id. Players without one get a preset picked
  /// from [seed] (their player id), so it never changes between launches.
  factory AvatarSource.of(String? avatar, String seed) {
    if (avatar == 'anon') return const AnonymousAvatar();
    if (avatar != null && avatar.startsWith('f:')) {
      final file = AvatarStore.file(avatar.substring(2));
      if (file != null && file.existsSync()) return PhotoAvatar(file);
    }
    var index = seed.hashCode.abs() % kAvatarPresets.length;
    if (avatar != null && avatar.startsWith('p:')) {
      index =
          (int.tryParse(avatar.substring(2)) ?? index) % kAvatarPresets.length;
    }
    return PresetAvatar(kAvatarPresets[index]);
  }
}

class PresetAvatar extends AvatarSource {
  const PresetAvatar(this.preset);
  final AvatarPreset preset;
}

/// A runner who chose to be anonymous: a plain grey silhouette.
class AnonymousAvatar extends AvatarSource {
  const AnonymousAvatar();
}

class PhotoAvatar extends AvatarSource {
  const PhotoAvatar(this.file);
  final File file;
}

/// Photos live in <documents>/avatars. Set up once in main().
class AvatarStore {
  AvatarStore._();

  static Directory? _dir;

  static Future<void> init(Directory documents) async {
    final dir = Directory('${documents.path}/avatars');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
  }

  static File? file(String name) =>
      _dir == null ? null : File('${_dir!.path}/$name');

  /// Opens the gallery or camera, saves a small copy, returns the avatar
  /// id ('f:<file>'), or null if cancelled.
  static Future<String?> pick(ImageSource source) async {
    final dir = _dir;
    if (dir == null) return null;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return null;
    // A new name each time, so cached images and map icons refresh.
    final name = 'me_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy('${dir.path}/$name');
    // Old photos are no longer referenced.
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith(name)) f.deleteSync();
    }
    return 'f:$name';
  }
}
