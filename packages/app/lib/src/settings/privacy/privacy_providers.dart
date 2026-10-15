import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../../session/providers.dart';

/// The privacy controller of the running session.
final privacyControllerProvider =
    Provider.autoDispose<PrivacySettingsController>(
      (ref) => ref.watch(telegramSessionProvider).requireValue.security,
    );

/// Every privacy setting, asked for once and then kept up to date by
/// TDLib's updates and by changes made here.
final privacyChoicesProvider =
    StreamProvider.autoDispose<Map<PrivacyRule, PrivacyChoice>>((ref) async* {
      final privacy = ref.watch(privacyControllerProvider);
      final changes = StreamController<void>();
      final subscription = privacy.changes.listen((_) => changes.add(null));
      ref.onDispose(() {
        unawaited(subscription.cancel());
        unawaited(changes.close());
      });
      yield await privacy.choices();
      await for (final _ in changes.stream) {
        yield {
          for (final rule in PrivacyRule.values) rule: ?privacy.cached(rule),
        };
      }
    });

/// How many people and chats are blocked; asked again after a change.
final blockedCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final privacy = ref.watch(privacyControllerProvider);
  final subscription = privacy.blockedChanges.listen(
    (_) => ref.invalidateSelf(),
  );
  ref.onDispose(subscription.cancel);
  return (await privacy.blocked(limit: 1)).totalCount;
});
