import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models.dart';

/// Local-only persistence: one JSON file for the game, one for the run in
/// progress (so a crash mid-run loses nothing).
///
/// Behind this interface so it can be swapped for drift or a real backend
/// later without touching the UI.
class GameRepository {
  GameRepository._(this._dir);

  final Directory _dir;
  Future<void> _queue = Future.value();

  File get _stateFile => File('${_dir.path}/runio_state.json');
  File get _activeFile => File('${_dir.path}/runio_active_run.json');

  static Future<GameRepository> open() async =>
      GameRepository._(await getApplicationDocumentsDirectory());

  /// Loads the game and rescues any run that was in progress when the app
  /// was killed.
  Future<GameData> loadWithRecovery() async {
    var data = await _load();
    final active = await _readJson(_activeFile);
    if (active != null) {
      try {
        final rec = RunRecord.fromJson(active);
        if (rec.distanceM >= 20 || rec.cells.isNotEmpty) {
          data = data.copyWith(runs: [rec, ...data.runs]);
          await save(data);
        }
      } catch (_) {
        // Unreadable snapshot. Drop it.
      }
      await clearActiveRun();
    }
    return data;
  }

  Future<GameData> _load() async {
    final json = await _readJson(_stateFile);
    if (json == null) return GameData.empty();
    try {
      return GameData.fromJson(json);
    } catch (_) {
      // Keep the broken file around for debugging, start fresh.
      await _stateFile.rename('${_stateFile.path}.corrupt');
      return GameData.empty();
    }
  }

  Future<Map<String, dynamic>?> _readJson(File f) async {
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(GameData data) => _write(_stateFile, data.toJson());

  Future<void> saveActiveRun(RunRecord snapshot) =>
      _write(_activeFile, snapshot.toJson());

  Future<void> clearActiveRun() => _enqueue(() => _delete(_activeFile));

  Future<void> wipe() => _enqueue(() async {
    await _delete(_stateFile);
    await _delete(_activeFile);
  });

  /// Atomic write: write to .tmp then rename, so a crash never leaves a
  /// half-written file.
  Future<void> _write(File f, Map<String, dynamic> json) {
    final text = jsonEncode(json);
    return _enqueue(() async {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(f.path);
    });
  }

  /// Serialises all disk work so writes never interleave.
  Future<void> _enqueue(Future<void> Function() job) {
    final next = _queue.then((_) => job()).catchError((Object _) {});
    _queue = next;
    return next;
  }

  Future<void> _delete(File f) async {
    if (await f.exists()) await f.delete();
  }
}
