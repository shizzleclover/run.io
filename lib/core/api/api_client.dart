import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'session.dart';

/// Something the server said no to, ready to show. [code] is stable and
/// safe to branch on; [message] is written for the runner.
class ApiException implements Exception {
  const ApiException(
    this.status,
    this.code,
    this.message, {
    this.fields = const {},
    this.extra = const {},
  });

  /// No connection, or the server didn't answer.
  const ApiException.offline()
    : status = 0,
      code = 'offline',
      message = "Can't reach run.io. Check your connection and try again.",
      fields = const {},
      extra = const {};

  final int status;
  final String code;
  final String message;

  /// Field name -> problems, for forms: {'username': ['That username is taken.']}.
  final Map<String, List<String>> fields;

  /// Anything else the error carried, e.g. 'email' or 'retryAfter'.
  final Map<String, dynamic> extra;

  String? field(String name) => fields[name]?.first;

  factory ApiException.fromBody(int status, Object? body) {
    final error = body is Map ? body['error'] : null;
    if (error is! Map) {
      return ApiException(
        status,
        'http_$status',
        'Something went wrong. Try again.',
      );
    }
    final fields = <String, List<String>>{
      for (final e in (error['fields'] as Map? ?? const {}).entries)
        e.key as String: List<String>.from(e.value as List),
    };
    return ApiException(
      status,
      error['code'] as String? ?? 'http_$status',
      error['message'] as String? ?? 'Something went wrong. Try again.',
      fields: fields,
      extra: {
        for (final e in error.entries)
          if (!const {'code', 'message', 'fields'}.contains(e.key))
            e.key as String: e.value,
      },
    );
  }

  @override
  String toString() => 'ApiException($status, $code: $message)';
}

/// JSON over HTTPS to the run.io API, with dart:io only.
///
/// Adds the access token, and when it has expired, swaps the refresh token
/// for a new pair once and retries. Only one refresh runs at a time: the
/// server ends every session if an old refresh token is used twice.
class ApiClient {
  ApiClient(this.base, this.sessions);

  final Uri base;

  /// Cleared when the server ends the session (signed out elsewhere,
  /// password reset, banned); the app listens and goes back to sign-in.
  final SessionStore sessions;

  final _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 30);

  Future<Map<String, dynamic>?>? _refreshing;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);
  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);
  Future<dynamic> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);
  Future<dynamic> delete(String path, [Object? body]) =>
      _send('DELETE', path, body: body);

  /// For calls before signing in (register, login, reset).
  Future<dynamic> postPublic(String path, [Object? body]) =>
      _send('POST', path, body: body, auth: false);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
    bool retried = false,
  }) async {
    final token = sessions.current?.accessToken;
    final uri = base.replace(
      path: '${base.path.replaceAll(RegExp(r'/$'), '')}/v1$path',
      queryParameters: query,
    );
    final int status;
    final Object? json;
    try {
      final req = await _http.openUrl(method, uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (auth && token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(const Duration(seconds: 30));
      final text = await res.transform(utf8.decoder).join();
      status = res.statusCode;
      json = text.isEmpty ? null : jsonDecode(text);
    } on SocketException {
      throw const ApiException.offline();
    } on HttpException {
      throw const ApiException.offline();
    } on HandshakeException {
      throw const ApiException.offline();
    } on TimeoutException {
      throw const ApiException.offline();
    }

    if (status < 300) return json;
    final error = ApiException.fromBody(status, json);
    if (status == 401 && auth && !retried && token != null) {
      if (await _refresh() != null) {
        return _send(method, path, body: body, query: query, retried: true);
      }
    }
    throw error;
  }

  /// New tokens, or null if the session is over.
  Future<Map<String, dynamic>?> _refresh() {
    final pending = _refreshing;
    if (pending != null) return pending;
    final future = _doRefresh();
    _refreshing = future;
    future.whenComplete(() => _refreshing = null);
    return future;
  }

  Future<Map<String, dynamic>?> _doRefresh() async {
    final session = sessions.current;
    if (session == null) return null;
    try {
      final res =
          await _send(
                'POST',
                '/auth/refresh',
                body: {'refreshToken': session.refreshToken},
                auth: false,
              )
              as Map<String, dynamic>;
      await sessions.save(
        session.copyWith(
          accessToken: res['accessToken'] as String,
          refreshToken: res['refreshToken'] as String,
        ),
      );
      return res;
    } on ApiException catch (e) {
      // Offline: keep the session and try again later.
      if (e.code != 'offline') await sessions.clear();
      return null;
    }
  }
}
