import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../session/providers.dart';

/// The session's contacts and known users.
final contactsControllerProvider = Provider<ContactsController>(
  (ref) => ref.watch(telegramSessionProvider).requireValue.contacts,
);

/// The contacts sorted by name, loaded from TDLib on first use and kept
/// current. Emits nothing until the list has loaded.
///
/// Disposed when nothing shows it, so a load that failed is tried again
/// the next time the list opens.
final contactsProvider = StreamProvider.autoDispose<List<ContactUser>>((ref) {
  final contacts = ref.watch(contactsControllerProvider);
  late final StreamController<List<ContactUser>> controller;
  StreamSubscription<void>? subscription;
  controller = StreamController<List<ContactUser>>(
    onListen: () {
      subscription = contacts.changes.listen((_) {
        if (contacts.isLoaded) controller.add(contacts.contacts);
      });
      if (contacts.isLoaded) {
        controller.add(contacts.contacts);
      } else {
        // A failed load shows an empty list until the next open.
        unawaited(
          contacts.load().catchError((Object _) {
            if (!controller.isClosed) controller.add(const []);
          }),
        );
      }
    },
    onCancel: () => subscription?.cancel(),
  );
  ref.onDispose(controller.close);
  return controller.stream;
});
