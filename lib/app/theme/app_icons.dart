import 'package:flutter/widgets.dart';

/// The Phosphor fonts ship with the phosphor_flutter package. Its Dart
/// classes don't compile on current Flutter (they extend IconData, now a
/// final class), so the icons are referenced by font and codepoint here.
const _pkg = 'phosphor_flutter';

/// Every icon in the app, in one place: Phosphor, regular weight for
/// actions and outlines, fill for selected tabs and solid controls. Screens
/// use these names, never an icon set directly, so the look stays uniform.
class AppIcons {
  AppIcons._();

  // Tabs (regular when idle, fill when selected)
  static const home = IconData(
    0xe2c2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const homeActive = IconData(
    0xe2c2,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
  );
  static const map = IconData(
    0xe31a,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const mapActive = IconData(
    0xe31a,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
  );
  static const ranks = IconData(
    0xe67e,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const ranksActive = IconData(
    0xe67e,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
  );
  static const profile = IconData(
    0xe4c2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const profileActive = IconData(
    0xe4c2,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
  );

  // Run controls
  static const play = IconData(
    0xe3d0,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
  );
  static const pause = IconData(
    0xe39e,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
  );
  static const stop = IconData(
    0xe46c,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
  );
  static const recenter = IconData(
    0xe1d8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const history = IconData(
    0xe242,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const historyOn = IconData(
    0xe242,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
  );
  static const loop = IconData(
    0xe634,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const weakGps = IconData(
    0xedd4,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const cooldown = IconData(
    0xe2b8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const cut = IconData(
    0xeae0,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const territory = IconData(
    0xe2ae,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );

  // General
  static const settings = IconData(
    0xe272,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const edit = IconData(
    0xe3b4,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const chevron = IconData(
    0xe13a,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const forward = IconData(
    0xe06c,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const check = IconData(
    0xe182,
    fontFamily: 'PhosphorBold',
    fontPackage: _pkg,
  );
  static const share = IconData(
    0xeaf0,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const delete = IconData(
    0xe4a6,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const refresh = IconData(
    0xe094,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const camera = IconData(
    0xe10e,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const gallery = IconData(
    0xe836,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const dice = IconData(
    0xe1ee,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const download = IconData(
    0xe20c,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const downloaded = IconData(
    0xe184,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const location = IconData(
    0xe316,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const locationOff = IconData(
    0xe318,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const streak = IconData(
    0xe242,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
  );
  static const invite = IconData(
    0xe4d0,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const followers = IconData(
    0xe68e,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const post = IconData(
    0xe45e,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const story = IconData(
    0xe1e0,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const close = IconData(
    0xe4f6,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );

  // Appearance
  static const dark = IconData(
    0xe330,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const light = IconData(
    0xe472,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const auto = IconData(
    0xe18c,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );

  // Privacy
  static const visible = IconData(
    0xe220,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const hidden = IconData(
    0xe224,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const nearby = IconData(
    0xe5e8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const anonymous = IconData(
    0xe4c4,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
  );

  // Onboarding
  static const run = IconData(
    0xe730,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );
  static const lightning = IconData(
    0xe2de,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
  );

  /// Built-in avatars: filled, so they read at small sizes on the map.
  static const List<IconData> avatars = [
    IconData(0xe730, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe2de, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe242, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe3fe, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe648, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe614, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe46a, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe7ae, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe472, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe330, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe33c, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe716, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe67e, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xed60, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe210, fontFamily: 'PhosphorFill', fontPackage: _pkg),
    IconData(0xe2a8, fontFamily: 'PhosphorFill', fontPackage: _pkg),
  ];
}
