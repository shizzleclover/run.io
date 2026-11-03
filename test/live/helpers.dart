// Shared setup for tests that talk to a real backend. See the README in
// this folder's tests for how to start one.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runio/core/api/api_client.dart';
import 'package:runio/core/api/session.dart';
import 'package:runio/core/env.dart';
import 'package:runio/core/models.dart';
import 'package:runio/core/storage/game_repository.dart';
import 'package:runio/engine/geo.dart';
import 'package:runio/state/account.dart';
import 'package:runio/state/game_controller.dart';
import 'package:runio/state/location_providers.dart';

/// The server's log, where console-mailed codes land. Null: skip.
final mailLog = Platform.environment['RUNIO_MAIL_LOG'];
const skipLive =
    'Needs a running backend (see test/live/server_presence_test.dart)';

const ui = LatLng(7.4443, 3.8995);

/// The newest code emailed to [email], read from the server log.
Future<String> codeFor(String email) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final lines = (await File(mailLog!).readAsLines()).reversed;
  for (final line in lines) {
    if (!line.contains('"to":"$email"')) continue;
    final m = RegExp(r'(\d{6}) is your run\.io code').firstMatch(line);
    if (m != null) return m.group(1)!;
  }
  throw StateError('No code for $email in the log');
}

/// A phone signed in to a fresh, verified account.
class TestPhone {
  TestPhone._(this.container, this.email, this.password);

  final ProviderContainer container;
  final String email;
  String password;

  String get id => container.read(gameProvider).user!.id;
  String get username => container.read(accountProvider)!.username;

  static Future<TestPhone> signUp(String name) async {
    final dir = await Directory.systemTemp.createTemp('runio');
    final store = await SessionStore.open(dir);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = '${name.toLowerCase()}$stamp@test.dev';
    const password = 'agbowo-loops-42';
    final container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(GameRepository.at(dir)),
        initialDataProvider.overrideWithValue(
          GameData(
            user: Player(id: 'me_$stamp', name: name, color: 0xFFFF5A1F),
            home: ui,
            homeState: 'OY',
          ),
        ),
        sessionStoreProvider.overrideWithValue(store),
        positionProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    final account = container.read(accountProvider.notifier);
    await account.register(
      email: email,
      username: '$name${stamp % 1000000}',
      password: password,
      confirmPassword: password,
    );
    await account.verifyEmail(email, await codeFor(email));
    return TestPhone._(container, email, password);
  }
}

/// A raw client, for checking things the app never does itself.
ApiClient rawClient(SessionStore store) =>
    ApiClient(Uri.parse(Env.apiUrl), store);
