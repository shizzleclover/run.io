// Every endpoint the app uses, called the way the app calls it, against a
// real backend. Skipped unless one is up; see server_presence_test.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runio/core/api/api_client.dart';
import 'package:runio/core/api/runio_api.dart';
import 'package:runio/core/models.dart';
import 'package:runio/engine/geo.dart';
import 'package:runio/state/account.dart';
import 'package:runio/state/cloud_sync.dart';
import 'package:runio/state/game_controller.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  late TestPhone ada;
  late TestPhone bayo;
  RunioApi api(TestPhone p) => p.container.read(runioApiProvider)!;

  final skip = mailLog == null ? skipLive : false;
  tearDownAll(() {
    if (mailLog == null) return; // skipped: no phones were made
    ada.container.dispose();
    bayo.container.dispose();
  });

  test('sign up, verify, config and the version gate', () async {
    ada = await TestPhone.signUp('Ada');
    bayo = await TestPhone.signUp('Bayo');
    expect(ada.id, isNot(startsWith('me_')), reason: 'took the account id');
    final config = await api(ada).config();
    expect((config['areas'] as List).length, greaterThan(10));
    expect(await ada.container.read(updateRequiredProvider.future), isFalse);
    expect(compareVersions('1.0.0', '1.0.1'), -1);
    expect(compareVersions('1.10.0', '1.9.9'), 1);
  }, skip: skip);

  test('profile, username and goals', () async {
    final sync = ada.container.read(cloudSyncProvider);
    ada.container.read(gameProvider.notifier).recolor(0xFF3B82F6);
    await sync.pushProfile();
    expect((await api(ada).me())['color'], 0x3B82F6);

    final name = 'Ada_${DateTime.now().millisecond}';
    await ada.container.read(accountProvider.notifier).changeUsername(name);
    expect(ada.container.read(gameProvider).user!.name, name);

    ada.container
        .read(gameProvider.notifier)
        .updateSettings(
          (s) => s.copyWith(weeklyDistanceGoalM: 21000, weeklyRunsGoal: 4),
        );
    await sync.pushGoals();
    expect((await api(ada).goals())['goalDistanceM'], 21000);
    ada.container
        .read(gameProvider.notifier)
        .updateSettings((s) => s.copyWith(weeklyDistanceGoalM: 5000));
    await sync.pullGoals();
    expect(
      ada.container.read(gameProvider).settings.weeklyDistanceGoalM,
      21000,
    );

    final prefs = await api(ada).client.put('/me/notifications', {
      'quietHours': {'start': 22, 'end': 7},
    });
    expect((prefs as Map)['quietHours'], {'start': 22, 'end': 7});
  }, skip: skip);

  test('runs upload, restore and delete', () async {
    final sync = ada.container.read(cloudSyncProvider);
    final game = ada.container.read(gameProvider.notifier);
    final start = DateTime.now().subtract(const Duration(minutes: 20));
    final run = RunRecord(
      id: 'phone-run-1',
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 10)),
      distanceM: 1500,
      movingSeconds: 560,
      path: [ui, Geo.offset(ui, 200, 0), Geo.offset(ui, 400, 0)],
      cells: const [],
      stolenFrom: const {},
    );
    game.addRun(run);
    await sync.pushRuns();
    expect(await api(ada).runIdFor('phone-run-1'), isNotNull);

    // A new phone: wipe and pull it back down.
    game.removeRun('phone-run-1');
    await sync.pullRuns();
    expect(
      ada.container.read(gameProvider).runs.map((r) => r.id),
      contains('phone-run-1'),
    );

    await sync.deleteRun('phone-run-1');
    expect(await api(ada).runIdFor('phone-run-1'), isNull);
  }, skip: skip);

  test('follows, friends, search, feed', () async {
    await ada.container.read(cloudSyncProvider).toggleFollow(bayo.id);
    await bayo.container.read(cloudSyncProvider).toggleFollow(ada.id);
    expect(ada.container.read(gameProvider).following, contains(bayo.id));

    final friends = await api(ada).people('friends');
    expect(friends.map((c) => c['id']), [bayo.id]);
    expect((await api(ada).people('followers')).map((c) => c['id']), [bayo.id]);
    await bayo.container.read(cloudSyncProvider).syncFollowing();
    expect(bayo.container.read(gameProvider).following, {ada.id});

    final found = await api(bayo).search(ada.username.substring(0, 4));
    expect(found.map((c) => c['id']), contains(ada.id));
    final sheet = await api(bayo).player(ada.id);
    expect(sheet['followsYou'], isTrue);

    expect(await api(ada).unreadCount(), greaterThan(0));
    final feed = await api(ada).events();
    expect((feed['items'] as List).first['type'], 'new_follower');
    await api(ada).markRead();
    expect(await api(ada).unreadCount(), 0);
  }, skip: skip);

  test('block, unblock, report', () async {
    await api(bayo).block(ada.id);
    // Blocking ends follows both ways, and hides them from each other...
    expect(await api(ada).people('friends'), isEmpty);
    expect((await api(ada).player(bayo.id))['name'], 'Anonymous runner');
    // ...but your own blocked list still names them.
    final blocked = await api(bayo).people('blocked');
    expect(blocked.single['name'], ada.username);
    await api(bayo).unblock(ada.id);
    expect(await api(bayo).people('blocked'), isEmpty);
    await api(bayo).report(ada.id, 'offensive_name', details: 'test');
  }, skip: skip);

  test(
    'crews: create, preview, join, rename, code, hand over, remove',
    () async {
      final aSync = ada.container.read(cloudSyncProvider);
      final bSync = bayo.container.read(cloudSyncProvider);
      await aSync.createCrew('Agbowo Striders');
      final code = ada.container.read(gameProvider).user!.crewId!;

      final preview = await api(bayo).crewPreview(code);
      expect(preview['members'], 1);
      await bSync.joinCrew(code: code);
      expect(bayo.container.read(gameProvider).myCrew?.name, 'Agbowo Striders');

      await aSync.renameCrew('Agbowo Pacers');
      final rotated = await api(ada).rotateCrewCode();
      expect(rotated['code'], isNot(code));
      await expectLater(
        api(ada).crewPreview(code),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'crew_not_found'),
        ),
      );

      await api(ada).transferCrew(bayo.id);
      final afterTransfer = await api(bayo).removeCrewMember(ada.id);
      expect((afterTransfer['members'] as List).length, 1);
      await bSync.leaveCrew();
      expect(bayo.container.read(gameProvider).myCrew, isNull);

      // A crew made on the phone before accounts carries over by code.
      ada.container
          .read(gameProvider.notifier)
          .joinCrew(code: 'QW7K-8MNP', name: 'Old Phone Crew');
      await aSync.syncCrew();
      expect(
        (await api(ada).crewPreview('QW7K-8MNP'))['name'],
        'Old Phone Crew',
      );
    },
    skip: skip,
  );

  test('photo upload says clearly when storage is off', () async {
    await expectLater(
      api(
        ada,
      ).client.post('/me/avatar/upload-url', {'contentType': 'image/jpeg'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'uploads_off')),
    );
  }, skip: skip);

  test('password, email, reset, export', () async {
    // Change password; the old one stops working.
    await api(ada).changePassword(
      currentPassword: ada.password,
      password: 'new-route-2026',
      confirmPassword: 'new-route-2026',
    );
    ada.password = 'new-route-2026';
    await expectLater(
      ada.container
          .read(accountProvider.notifier)
          .signIn(ada.email, 'agbowo-loops-42'),
      throwsA(isA<ApiException>()),
    );

    // Change email: code to the new address.
    final newEmail = 'ada.new${DateTime.now().microsecondsSinceEpoch}@test.dev';
    await api(ada).requestEmailChange(newEmail, ada.password);
    final me = await api(ada).confirmEmailChange(await codeFor(newEmail));
    expect(me['email'], newEmail);

    // Forgot password, signed out, by code.
    final account = ada.container.read(accountProvider.notifier);
    await account.forgotPassword(newEmail);
    await account.resetPassword(
      email: newEmail,
      code: await codeFor(newEmail),
      password: 'third-loop-2026',
      confirmPassword: 'third-loop-2026',
    );
    expect(ada.container.read(accountProvider), isNotNull);

    final data = await api(ada).exportData();
    expect((data['profile'] as Map)['email'], newEmail);
  }, skip: skip);

  test('sign out everywhere, then delete the account', () async {
    await api(bayo).signOutEverywhere();
    // Access tokens live out their 15 minutes; the refresh is what's
    // refused. Expire this one and the app drops the session itself.
    final store = bayo.container.read(sessionStoreProvider);
    await store.save(store.current!.copyWith(accessToken: 'expired'));
    await expectLater(api(bayo).me(), throwsA(isA<ApiException>()));
    expect(bayo.container.read(accountProvider), isNull);

    await api(ada).requestDeletion('third-loop-2026');
    final email = (await api(ada).me())['email'] as String;
    await api(ada).deleteAccount(await codeFor(email));
    await ada.container.read(accountProvider.notifier).forget();
    expect(ada.container.read(accountProvider), isNull);
    expect(ada.container.read(gameProvider).user, isNull);
  }, skip: skip);
}
