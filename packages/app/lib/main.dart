import 'package:flutter/widgets.dart';
import 'package:mollygram/mollygram.dart';
import 'package:mollygram_core/mollygram_core.dart';

void main() {
  runApp(const MollygramApp(config: TelegramApiConfig.fromEnvironment));
}
