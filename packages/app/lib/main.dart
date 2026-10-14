import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_media/mollygram_media.dart';

import 'src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MollygramMedia.ensureInitialized();
  runApp(const ProviderScope(child: MollygramApp()));
}
