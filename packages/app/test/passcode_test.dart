import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/settings/privacy/passcode.dart';
import 'package:mollygram/src/settings/privacy/passcode_lock_screen.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('hashing', () {
    test('PBKDF2-HMAC-SHA256 matches the published vectors', () {
      List<int> key(int rounds) =>
          pbkdf2(utf8.encode('password'), utf8.encode('salt'), rounds);
      expect(
        _hex(key(1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        _hex(key(2)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
      expect(
        _hex(key(4096)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('a hash checks its passcode and nothing else', () async {
      final hash = await PasscodeHash.create('1234', iterations: 100);
      expect(await hash.verify('1234'), isTrue);
      expect(await hash.verify('1235'), isFalse);
      expect(await hash.verify(''), isFalse);
    });

    test('every hash has its own salt and keeps no passcode', () async {
      final a = await PasscodeHash.create('1234', iterations: 100);
      final b = await PasscodeHash.create('1234', iterations: 100);
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
      expect(jsonEncode(a.toJson()), isNot(contains('1234')));

      final read = PasscodeHash.fromJson(
        jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>,
      );
      expect(await read.verify('1234'), isTrue);
      expect(read.iterations, 100);
    });

    test('broken settings read as no passcode', () {
      expect(PasscodeSettings.fromJson('nope').enabled, isFalse);
      expect(
        PasscodeSettings.fromJson({
          'hash': {'salt': 1},
        }).enabled,
        isFalse,
      );
      expect(
        PasscodeSettings.fromJson({'autoLockMinutes': 7}).autoLockMinutes,
        60,
      );
    });
  });

  group('lock', () {
    late DateTime now;
    late MemoryPasscodeStorage storage;

    Future<ProviderContainer> create([Object? saved]) async {
      now = DateTime(2026, 10, 15, 9);
      storage = MemoryPasscodeStorage(saved);
      final container = ProviderContainer(
        overrides: [
          passcodeStorageProvider.overrideWithValue(storage),
          passcodeClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      container.read(passcodeLockProvider);
      await Future<void>.delayed(Duration.zero);
      return container;
    }

    Future<Object?> savedWith(String passcode, {int minutes = 5}) async =>
        jsonDecode(
          jsonEncode(
            PasscodeSettings(
              hash: await PasscodeHash.create(passcode, iterations: 100),
              autoLockMinutes: minutes,
            ).toJson(),
          ),
        );

    test('without a passcode nothing locks', () async {
      final container = await create();
      final lock = container.read(passcodeLockProvider.notifier);
      expect(container.read(passcodeLockProvider).loaded, isTrue);
      lock.lock();
      now = now.add(const Duration(hours: 2));
      lock.check();
      expect(container.read(passcodeLockProvider).locked, isFalse);
    });

    test('a saved passcode locks at launch and unlocks', () async {
      final container = await create(await savedWith('2580'));
      final lock = container.read(passcodeLockProvider.notifier);
      expect(container.read(passcodeLockProvider).locked, isTrue);
      expect(await lock.unlock('0000'), isFalse);
      expect(container.read(passcodeLockProvider).locked, isTrue);
      expect(await lock.unlock('2580'), isTrue);
      expect(container.read(passcodeLockProvider).locked, isFalse);
    });

    test('locks after the away time, counted from the last activity', () async {
      final container = await create(await savedWith('2580'));
      final lock = container.read(passcodeLockProvider.notifier);
      await lock.unlock('2580');

      now = now.add(const Duration(minutes: 4));
      lock
        ..activity()
        ..check();
      expect(container.read(passcodeLockProvider).locked, isFalse);

      now = now.add(const Duration(minutes: 4, seconds: 59));
      lock.check();
      expect(container.read(passcodeLockProvider).locked, isFalse);

      now = now.add(const Duration(seconds: 1));
      lock.check();
      expect(container.read(passcodeLockProvider).locked, isTrue);
    });

    test('turning on, changing and off is saved', () async {
      final container = await create();
      final lock = container.read(passcodeLockProvider.notifier);

      await lock.setPasscode('1111', iterations: 100);
      expect(container.read(passcodeLockProvider).settings.enabled, isTrue);
      expect(container.read(passcodeLockProvider).locked, isFalse);
      expect(PasscodeSettings.fromJson(storage.saved).enabled, isTrue);
      expect(jsonEncode(storage.saved), isNot(contains('1111')));

      await lock.setAutoLock(15);
      expect(PasscodeSettings.fromJson(storage.saved).autoLockMinutes, 15);

      await lock.setPasscode('2222', iterations: 100);
      expect(await lock.verify('1111'), isFalse);
      expect(await lock.verify('2222'), isTrue);
      expect(PasscodeSettings.fromJson(storage.saved).autoLockMinutes, 15);

      lock.lock();
      await lock.turnOff();
      expect(storage.saved, isNull);
      expect(container.read(passcodeLockProvider).locked, isFalse);
    });
  });

  group('lock screen', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      final saved = await tester.runAsync(
        () async => PasscodeSettings(
          hash: await PasscodeHash.create('2580', iterations: 100),
        ).toJson(),
      );
      final container = ProviderContainer(
        overrides: [
          passcodeStorageProvider.overrideWithValue(
            MemoryPasscodeStorage(saved),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildMgTheme(MgColors.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Material(
              child: PasscodeGate(child: Center(child: Text('Chats'))),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return container;
    }

    /// The auto-lock timer goes with the container, before the test
    /// checks for timers left running.
    Future<void> finish(WidgetTester tester, ProviderContainer c) async {
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }

    Future<void> enter(WidgetTester tester, String passcode) async {
      await tester.enterText(
        find.byKey(const ValueKey('passcodeField')),
        passcode,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('covers the window until the passcode is right', (
      tester,
    ) async {
      final container = await pump(tester);
      expect(find.text('Mollygram is locked'), findsOneWidget);
      // The chats are there, blurred, but can't be reached.
      expect(find.text('Chats'), findsOneWidget);

      await enter(tester, '1111');
      expect(find.text('Wrong passcode'), findsOneWidget);
      expect(find.text('Mollygram is locked'), findsOneWidget);

      await enter(tester, '2580');
      expect(find.text('Mollygram is locked'), findsNothing);
      await finish(tester, container);
    });

    testWidgets('command L locks right away', (tester) async {
      final container = await pump(tester);
      await enter(tester, '2580');
      expect(find.text('Mollygram is locked'), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(find.text('Mollygram is locked'), findsOneWidget);
      await finish(tester, container);
    });
  });
}
