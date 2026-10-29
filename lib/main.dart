import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/avatars.dart';
import 'core/env.dart';
import 'core/notifications.dart';
import 'core/storage/game_repository.dart';
import 'state/game_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  if (Env.hasMapboxToken) MapboxOptions.setAccessToken(Env.mapboxToken);

  await Notifications.init();
  await AvatarStore.init(await getApplicationDocumentsDirectory());
  final repo = await GameRepository.open();
  final data = await repo.loadWithRecovery();

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        initialDataProvider.overrideWithValue(data),
      ],
      child: const RunIoApp(),
    ),
  );
}
