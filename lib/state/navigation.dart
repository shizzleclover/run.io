import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/geo.dart';

/// Somewhere another tab wants the map to fly to (a leaderboard player, a
/// live runner, your fading land). The map screen consumes and clears it.
class MapFocus extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void focus(LatLng p) => state = p;
  void clear() => state = null;
}

final mapFocusProvider = NotifierProvider<MapFocus, LatLng?>(MapFocus.new);

/// Run history heatmap on the map. Shared so Home's heatmap card can open
/// the map with it switched on.
class HistoryVisible extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
}

final historyVisibleProvider = NotifierProvider<HistoryVisible, bool>(
  HistoryVisible.new,
);

/// Home's Start button asks the map to begin a run, so the start goes
/// through the same countdown wherever it was pressed. True while a start
/// is waiting for the map to pick it up.
class StartRequest extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;
  void consume() => state = false;
}

final startRequestProvider = NotifierProvider<StartRequest, bool>(
  StartRequest.new,
);
