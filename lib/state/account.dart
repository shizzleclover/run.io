import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/runio_api.dart';
import '../core/api/session.dart';
import '../core/constants.dart';
import '../core/env.dart';
import 'cloud_sync.dart';
import 'game_controller.dart';

/// Opened in main() before the app starts.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('Override in main()'),
);

/// Null when the app runs without a backend (no API_URL).
final apiProvider = Provider<ApiClient?>((ref) {
  if (!Env.hasApi) return null;
  return ApiClient(Uri.parse(Env.apiUrl), ref.watch(sessionStoreProvider));
});

/// Every app-facing endpoint, typed. Null without a backend.
final runioApiProvider = Provider<RunioApi?>((ref) {
  final client = ref.watch(apiProvider);
  return client == null ? null : RunioApi(client);
});

/// True when the server says this app is too old to play.
final updateRequiredProvider = FutureProvider<bool>((ref) async {
  final api = ref.watch(runioApiProvider);
  if (api == null) return false;
  try {
    final min = (await api.config())['minAppVersion'] as String? ?? '0';
    return compareVersions(kAppVersion, min) < 0;
  } on ApiException {
    return false; // offline: let them play
  }
});

/// -1, 0 or 1, comparing "1.2.10" with "1.10.0" number by number.
int compareVersions(String a, String b) {
  final x = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final y = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// Accounts are on: the app has a backend to sign in to.
bool get accountsEnabled => Env.hasApi;

/// Signed in to a backend: the server owns territory, ghosts and live
/// play. Otherwise the phone simulates them.
final serverModeProvider = Provider<bool>(
  (ref) => accountsEnabled && ref.watch(accountProvider) != null,
);

/// Who's signed in, or null.
final accountProvider = NotifierProvider<AccountController, Session?>(
  AccountController.new,
);

class AccountController extends Notifier<Session?> {
  @override
  Session? build() {
    final store = ref.watch(sessionStoreProvider);
    // Also fires when the server ends the session.
    store.onChange = (s) => state = s;
    return store.current;
  }

  ApiClient get _api => ref.read(apiProvider)!;
  SessionStore get _store => ref.read(sessionStoreProvider);

  /// Step 1 of signing up. A code goes to the email. Returns the email as
  /// the server stored it (lowercased).
  Future<String> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    final res =
        await _api.postPublic('/auth/register', {
              'email': email,
              'username': username,
              'password': password,
              'confirmPassword': confirmPassword,
            })
            as Map<String, dynamic>;
    return res['email'] as String;
  }

  /// Step 2: the code from the email. Signs you in.
  Future<void> verifyEmail(String email, String code) async {
    final res = await _api.postPublic('/auth/verify-email', {
      'email': email,
      'code': code,
    });
    await _signedIn(res as Map<String, dynamic>);
  }

  Future<void> resendCode(String email) =>
      _api.postPublic('/auth/resend-otp', {'email': email});

  /// Email or username. An unverified account throws `email_unverified`
  /// with the email in [ApiException.extra], after a fresh code is sent.
  Future<void> signIn(String identifier, String password) async {
    final res = await _api.postPublic('/auth/login', {
      'identifier': identifier,
      'password': password,
    });
    await _signedIn(res as Map<String, dynamic>);
  }

  Future<void> forgotPassword(String email) =>
      _api.postPublic('/auth/password/forgot', {'email': email});

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
    required String confirmPassword,
  }) async {
    final res = await _api.postPublic('/auth/password/reset', {
      'email': email,
      'code': code,
      'password': password,
      'confirmPassword': confirmPassword,
    });
    await _signedIn(res as Map<String, dynamic>);
  }

  /// Usernames are unique, so the server decides. Returns the new one.
  Future<String> changeUsername(String username) async {
    final res =
        await _api.patch('/me/username', {'username': username})
            as Map<String, dynamic>;
    final name = res['username'] as String;
    final session = state;
    if (session != null) await _store.save(session.copyWith(username: name));
    ref.read(gameProvider.notifier).rename(name);
    return name;
  }

  /// Everything on this phone belongs to the account, so it goes too.
  /// Signing back in restores profile, runs and crew.
  Future<void> signOut() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Offline or already ended: signing out locally is what matters.
    }
    // Phone data first, so the app lands on onboarding, not sign-in.
    await ref.read(gameProvider.notifier).wipe();
    await _store.clear();
  }

  /// After an email change.
  Future<void> updateEmail(String email) async {
    final session = state;
    if (session != null) await _store.save(session.copyWith(email: email));
  }

  /// The account is gone (deleted): drop everything without calling the
  /// server, which no longer knows this session.
  Future<void> forget() async {
    await ref.read(gameProvider.notifier).wipe();
    await _store.clear();
  }

  Future<void> _signedIn(Map<String, dynamic> res) async {
    final user = res['user'] as Map<String, dynamic>;
    await _store.save(
      Session(
        userId: user['id'] as String,
        username: user['username'] as String,
        email: user['email'] as String,
        accessToken: res['accessToken'] as String,
        refreshToken: res['refreshToken'] as String,
      ),
    );
    await ref.read(cloudSyncProvider).afterSignIn(user);
  }
}
