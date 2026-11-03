import 'package:share_plus/share_plus.dart';

import 'env.dart';
import 'models.dart';

/// Every invite says where to get the app, when we know.
String _withLink(String text) =>
    Env.inviteUrl.isEmpty ? text : '$text\n\nGet run.io: ${Env.inviteUrl}';

/// "Come take my block": the general invite, from Home and share cards.
String appInvite({required String? area}) => _withLink(
  'I\'m claiming ${area ?? 'my area'} on run.io: run loops, own the '
  'streets. Come take my block if you can.',
);

/// Crew invite. Paste the whole message into "Join a crew" and the app
/// finds the name and code in it.
String crewInvite(Crew crew) =>
    _withLink('Join my crew "${crew.name}" on run.io. Crew code: ${crew.code}');

Future<void> shareText(String text) =>
    SharePlus.instance.share(ShareParams(text: text));

/// Pulls a crew code, and the name if there is one, out of whatever was
/// pasted: a code on its own or a whole invite message.
({String code, String? name})? parseCrewInvite(String input) {
  final code = RegExp(
    r'\b([A-HJ-NP-Z2-9]{4})-?([A-HJ-NP-Z2-9]{4})\b',
  ).firstMatch(input.toUpperCase());
  if (code == null) return null;
  final name = RegExp(r'["“]([^"”]{1,40})["”]').firstMatch(input);
  return (
    code: '${code.group(1)}-${code.group(2)}',
    name: name?.group(1)?.trim(),
  );
}

/// Text that goes out with a run's share card.
String runShareText(String claimed) => _withLink(
  'Just claimed $claimed on run.io. Come take my block if you can.',
);
