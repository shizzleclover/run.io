import '../../app/theme/colors.dart';
import '../models.dart';

/// A player card from the server (map, boards, feeds) as a [Player].
/// Ghosts come back as rivals, and private runners as not discoverable,
/// so the rest of the app treats them as it always has.
Player playerFromCard(Map<String, dynamic> card) {
  final id = card['id'] as String;
  final rgb = card['color'] as int?;
  final crew = card['crew'] as Map<String, dynamic>?;
  return Player(
    id: id,
    name: card['name'] as String,
    color: rgb == null
        ? AppColors.playerColors[id.hashCode.abs() %
              AppColors.playerColors.length]
        : 0xFF000000 | rgb,
    avatar: card['avatar'] as String?,
    isRival: card['isGhost'] as bool? ?? false,
    discoverable: !(card['isAnonymous'] as bool? ?? false),
    crewId: crew?['code'] as String?,
  );
}

Crew? crewFromCard(Map<String, dynamic> card) {
  final crew = card['crew'] as Map<String, dynamic>?;
  if (crew == null) return null;
  return Crew(
    code: crew['code'] as String,
    name: crew['name'] as String,
    ghost: card['isGhost'] as bool? ?? false,
  );
}
