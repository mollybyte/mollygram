import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../preferences.dart';

/// A message of a few emoji: [big] with "Large emoji" on, [small] (the
/// usual text) with it off.
class LargeEmoji extends ConsumerWidget {
  const LargeEmoji({super.key, required this.big, required this.small});

  final Widget big;
  final Widget small;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(preferencesProvider.select((p) => p.largeEmoji)) ? big : small;
}

/// Whether animated stickers drawn now play on ("Loop animated stickers").
/// Read when a sticker is built: one already playing keeps going.
bool loopStickersOf(BuildContext context) => ProviderScope.containerOf(
  context,
  listen: false,
).read(preferencesProvider).loopStickers;
