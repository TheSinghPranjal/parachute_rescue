import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/audio_service.dart';
import 'core/services/storage_service.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  StorageService storage;
  try {
    storage = await PrefsStorageService.create();
  } on Object catch (e) {
    // Never block the menu on storage: fall back to an in-memory store.
    debugPrint('Storage unavailable, using memory: $e');
    storage = MemoryStorageService();
  }

  final audio = FlameAudioService();
  await audio.preload();

  runApp(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
        audioProvider.overrideWithValue(audio),
      ],
      child: const SkyRescueApp(),
    ),
  );
}
