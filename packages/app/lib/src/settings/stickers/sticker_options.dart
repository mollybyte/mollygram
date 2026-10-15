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

/// Whether animated stickers play on ("Loop animated stickers"). Watched,
/// so the stickers on screen follow the switch.
final loopStickersProvider = Provider<bool>(
  (ref) => ref.watch(preferencesProvider.select((p) => p.loopStickers)),
);
