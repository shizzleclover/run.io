import 'api_client.dart';

/// Every endpoint the app uses, in one place, named after what it does.
/// Screens call these rather than writing paths, so the whole surface is
/// visible here and test/live/api_contract_test.dart can cover it.
///
/// Sign-in, sync and live play keep their own calls in AccountController,
/// CloudSync and ServerPresence; those are covered by the same test.
class RunioApi {
  const RunioApi(this.client);

  final ApiClient client;

  // ---------- app ----------

  /// Minimum app version, launch areas, game constants.
  Future<Map<String, dynamic>> config() async =>
      await client.get('/config') as Map<String, dynamic>;

  // ---------- account ----------

  Future<Map<String, dynamic>> me() async =>
      await client.get('/me') as Map<String, dynamic>;

  /// Ends every other session. This phone stays signed in.
  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String confirmPassword,
  }) => client.patch('/me/password', {
    'currentPassword': currentPassword,
    'password': password,
    'confirmPassword': confirmPassword,
  });

  /// Step 1: a code goes to [newEmail].
  Future<void> requestEmailChange(String newEmail, String password) =>
      client.post('/me/email', {'newEmail': newEmail, 'password': password});

  /// Step 2. Returns the updated profile.
  Future<Map<String, dynamic>> confirmEmailChange(String code) async =>
      await client.post('/me/email/confirm', {'code': code})
          as Map<String, dynamic>;

  Future<void> signOutEverywhere() => client.post('/auth/logout-all');

  /// Step 1 of deleting: password, then a code by email.
  Future<void> requestDeletion(String password) =>
      client.post('/me/delete/request', {'password': password});

  /// Step 2: gone for good.
  Future<void> deleteAccount(String code) =>
      client.delete('/me', {'code': code});

  /// Everything the server holds about you.
  Future<Map<String, dynamic>> exportData() async =>
      await client.get('/me/export') as Map<String, dynamic>;

  // ---------- runs and goals ----------

  Future<void> deleteRun(String serverId) => client.delete('/runs/$serverId');

  /// Finds the server's id for a run this phone made.
  Future<String?> runIdFor(String clientId) async {
    String? before;
    for (var page = 0; page < 20; page++) {
      final res =
          await client.get('/runs', query: {'limit': '50', 'before': ?before})
              as Map<String, dynamic>;
      for (final r in (res['items'] as List).cast<Map<String, dynamic>>()) {
        if (r['clientId'] == clientId) return r['id'] as String;
      }
      before = res['nextBefore'] as String?;
      if (before == null) return null;
    }
    return null;
  }

  Future<Map<String, dynamic>> goals() async =>
      await client.get('/me/goals') as Map<String, dynamic>;

  Future<Map<String, dynamic>> setGoals({
    required int distanceM,
    required int runs,
  }) async =>
      await client.put('/me/goals', {
            'goalDistanceM': distanceM,
            'goalRuns': runs,
          })
          as Map<String, dynamic>;

  // ---------- people ----------

  /// The player sheet: card plus land, and follows both ways.
  Future<Map<String, dynamic>> player(String id) async =>
      await client.get('/players/$id') as Map<String, dynamic>;

  Future<List<Map<String, dynamic>>> search(String query) async {
    final res =
        await client.get('/players/search', query: {'q': query})
            as Map<String, dynamic>;
    return (res['items'] as List).cast<Map<String, dynamic>>();
  }

  /// 'following', 'followers', 'friends' or 'blocked'.
  Future<List<Map<String, dynamic>>> people(String list) async {
    final res =
        await client.get('/me/$list', query: {'limit': '100'})
            as Map<String, dynamic>;
    return (res['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> block(String id) => client.post('/players/$id/block');
  Future<void> unblock(String id) => client.delete('/players/$id/block');

  /// [reason]: cheating, offensive_name, offensive_avatar, harassment, other.
  Future<void> report(String id, String reason, {String? details}) => client
      .post('/players/$id/report', {'reason': reason, 'details': ?details});

  // ---------- crews ----------

  /// "Agbowo Striders, 12 runners" before you join.
  Future<Map<String, dynamic>> crewPreview(String code) async =>
      await client.get('/crews/$code') as Map<String, dynamic>;

  Future<Map<String, dynamic>> rotateCrewCode() async =>
      await client.post('/crews/mine/rotate-code') as Map<String, dynamic>;

  Future<Map<String, dynamic>> removeCrewMember(String userId) async =>
      await client.delete('/crews/mine/members/$userId')
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> transferCrew(String userId) async =>
      await client.post('/crews/mine/transfer', {'userId': userId})
          as Map<String, dynamic>;

  // ---------- feed ----------

  Future<Map<String, dynamic>> events({int? before}) async =>
      await client.get(
            '/events',
            query: {'limit': '30', if (before != null) 'before': '$before'},
          )
          as Map<String, dynamic>;

  Future<int> unreadCount() async {
    final res =
        await client.get('/events/unread-count') as Map<String, dynamic>;
    return res['unread'] as int;
  }

  Future<void> markRead() => client.post('/events/read', const {});
}
