/// Territory decay. Land you don't run through goes stale, then neutral,
/// so a big early claim can't sit there forever.
///
/// Days are whole-day numbers (e.g. days since 1970). Pure Dart.
class DecayRule {
  const DecayRule({this.staleAfterDays = 14, this.loseAfterDays = 30});

  /// Older than this: drawn faded, and rivals go for it first.
  final int staleAfterDays;

  /// Older than this: you lose it and it becomes unclaimed.
  final int loseAfterDays;

  bool isStale(int touchedDay, int today) =>
      today - touchedDay >= staleAfterDays;

  bool isLost(int touchedDay, int today) => today - touchedDay >= loseAfterDays;

  /// Your cells that are stale but not yet lost.
  Set<String> stale({
    required Map<String, String> owners,
    required Map<String, int> touched,
    required String playerId,
    required int today,
  }) => {
    for (final e in owners.entries)
      if (e.value == playerId &&
          isStale(touched[e.key] ?? today, today) &&
          !isLost(touched[e.key] ?? today, today))
        e.key,
  };

  /// Owners with your expired cells removed. Unknown touch dates count as
  /// fresh, so old saves don't lose everything at once.
  Map<String, String> expire({
    required Map<String, String> owners,
    required Map<String, int> touched,
    required String playerId,
    required int today,
  }) => {
    for (final e in owners.entries)
      if (e.value != playerId || !isLost(touched[e.key] ?? today, today))
        e.key: e.value,
  };
}
