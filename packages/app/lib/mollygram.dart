import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_prototype/app_state.dart';
import 'package:mollygram_prototype/circle/circle_controller.dart';
import 'package:mollygram_prototype/main.dart';

class MollygramApp extends StatelessWidget {
  const MollygramApp({super.key, required this.config});

  final TelegramApiConfig config;

  @override
  Widget build(BuildContext context) =>
      PrototypeApp(app: AppState(), circle: CircleController(enabled: false));
}
