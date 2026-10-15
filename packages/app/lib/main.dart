import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_media/mollygram_media.dart';

import 'src/app.dart';
import 'src/settings/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MollygramMedia.ensureInitialized();
  // Read before the first frame, so the window opens in the chosen theme.
  final storage = FilePreferencesStorage();
  final preferences = await loadPreferences(storage);
  runApp(
    ProviderScope(
      overrides: [
        preferencesStorageProvider.overrideWithValue(storage),
        initialPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const MollygramApp(),
    ),
  );
}
