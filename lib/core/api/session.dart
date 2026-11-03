import 'dart:convert';
import 'dart:io';

/// Who's signed in on this phone, and what's been synced for them.
class Session {
  const Session({
    required this.userId,
    required this.username,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    this.syncedRuns = const {},
  });

  final String userId;
  final String username;
  final String email;
  final String accessToken;
  final String refreshToken;

  /// Ids of local runs already uploaded to this account.
  final Set<String> syncedRuns;

  Session copyWith({
    String? username,
    String? email,
    String? accessToken,
    String? refreshToken,
    Set<String>? syncedRuns,
  }) => Session(
    userId: userId,
    username: username ?? this.username,
    email: email ?? this.email,
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    syncedRuns: syncedRuns ?? this.syncedRuns,
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'email': email,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'syncedRuns': syncedRuns.toList(),
  };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    userId: j['userId'] as String,
    username: j['username'] as String,
    email: j['email'] as String,
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    syncedRuns: {...(j['syncedRuns'] as List? ?? const []).cast<String>()},
  );
}

/// The session, in a file in the app's private storage. Only this app can
/// read it on a normal phone; flutter_secure_storage would add the Android
/// Keystore on top.
class SessionStore {
  SessionStore._(this._file, this.current);

  final File _file;
  Session? current;

  /// Called whenever the session changes, including when it ends.
  void Function(Session?)? onChange;

  static Future<SessionStore> open(Directory dir) async {
    final file = File('${dir.path}/runio_session.json');
    Session? session;
    try {
      if (await file.exists()) {
        session = Session.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Unreadable: sign in again.
    }
    return SessionStore._(file, session);
  }

  Future<void> save(Session session) async {
    current = session;
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(session.toJson()), flush: true);
    await tmp.rename(_file.path);
    onChange?.call(session);
  }

  Future<void> clear() async {
    current = null;
    if (await _file.exists()) await _file.delete();
    onChange?.call(null);
  }
}
