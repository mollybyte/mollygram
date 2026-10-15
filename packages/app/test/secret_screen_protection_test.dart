import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/home/workspace.dart';
import 'package:mollygram/src/privacy/privacy_settings.dart';
import 'package:mollygram/src/secret/secret_chat.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

void main() {
  const channel = MethodChannel('mollygram/window');
  final secret = SecretChatsController.chatIdOf(5);
  const plain = 7;
  late List<bool> calls;
  late WorkspaceController workspace;
  late ProviderContainer container;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setContentProtection') {
            calls.add(call.arguments as bool);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pump(WidgetTester tester, {Workspace? initial}) async {
    workspace = WorkspaceController(initial);
    addTearDown(workspace.dispose);
    container = ProviderContainer(
      overrides: [
        workspaceControllerProvider.overrideWithValue(workspace),
        privacySettingsStorageProvider.overrideWithValue(
          MemoryPrivacySettingsStorage(),
        ),
        // Never starts: the settings only pass changes on to a session.
        telegramSessionProvider.overrideWith(
          (ref) => Completer<TelegramSession>().future,
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SecretScreenProtection(child: SizedBox()),
      ),
    );
    await tester.pump();
  }

  testWidgets('says the current state at start, even when off', (tester) async {
    await pump(tester);
    expect(calls, [false]);
  });

  testWidgets('protects while a secret chat is focused', (tester) async {
    await pump(tester);
    workspace.open(secret);
    await tester.pump();
    expect(calls, [false, true]);

    workspace.open(plain);
    await tester.pump();
    expect(calls, [false, true, false]);
  });

  testWidgets('starts protected when a secret chat is already open', (
    tester,
  ) async {
    await pump(tester, initial: Workspace.initial().open(secret));
    expect(calls, [true]);
  });

  testWidgets('a secret chat in the other pane of a split still counts', (
    tester,
  ) async {
    await pump(tester);
    workspace.open(secret);
    workspace.open(plain, target: OpenTarget.split);
    await tester.pump();
    expect(workspace.value.focusedChat, plain);
    expect(workspace.value.activeTab.panes, contains(secret));
    expect(calls.last, isTrue);

    // In another tab the secret chat is out of sight.
    workspace.newTab();
    await tester.pump();
    expect(calls.last, isFalse);
  });

  testWidgets('the allow switch turns it off and back on', (tester) async {
    await pump(tester);
    workspace.open(secret);
    await tester.pump();
    expect(calls.last, isTrue);

    final settings = container.read(privacySettingsProvider.notifier);
    settings.update((s) => s.copyWith(allowSecretScreenshots: true));
    await tester.pump();
    expect(calls.last, isFalse);

    settings.update((s) => s.copyWith(allowSecretScreenshots: false));
    await tester.pump();
    expect(calls.last, isTrue);
  });

  testWidgets('lifts the protection when it goes away', (tester) async {
    await pump(tester);
    workspace.open(secret);
    await tester.pump();
    expect(calls.last, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(calls.last, isFalse);
  });
}
