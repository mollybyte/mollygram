import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/notifications/notification_service.dart';
import 'package:mollygram/src/notifications/notification_settings.dart';
import 'package:mollygram/src/settings/privacy/passcode.dart';
import 'package:mollygram/src/settings/privacy/passcode_lock_screen.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// A keychain that fails on demand and counts its writes.
final class _FlakyStorage implements PasscodeStorage {
  _FlakyStorage([this.saved]);

  Object? saved;
  var readFails = false;
  var writeFails = false;
  var writes = 0;

  @override
  Future<Object?> read() async {
    if (readFails) throw PlatformException(code: 'keychain');
    return saved;
  }

  @override
  Future<void> write(Object? json) async {
    writes++;
    if (writeFails) throw PlatformException(code: 'keychain');
    saved = json;
  }
}

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

    test('only no entry reads as no passcode; a damaged one throws', () {
      expect(PasscodeSettings.fromJson(null).enabled, isFalse);
      expect(() => PasscodeSettings.fromJson('nope'), throwsFormatException);
      expect(
        () => PasscodeSettings.fromJson({
          'hash': {'salt': 1},
        }),
        throwsFormatException,
      );
      expect(
        PasscodeSettings.fromJson({'autoLockMinutes': 7}).autoLockMinutes,
        60,
      );
    });
  });

  group('lock', () {
    late DateTime now;
    late _FlakyStorage storage;

    Future<ProviderContainer> create([
      Object? saved,
      bool readFails = false,
    ]) async {
      now = DateTime(2026, 10, 15, 9);
      storage = _FlakyStorage(saved)..readFails = readFails;
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
      expect(await lock.unlock('0000'), UnlockResult.wrong);
      expect(container.read(passcodeLockProvider).locked, isTrue);
      expect(await lock.unlock('2580'), UnlockResult.unlocked);
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
      final off = PasscodeSettings.fromJson(storage.saved);
      expect(off.enabled, isFalse);
      expect(off.autoLockMinutes, 15);
      expect(container.read(passcodeLockProvider).locked, isFalse);
    });

    test('a keychain that fails to read keeps the window locked', () async {
      final container = await create(await savedWith('2580'), true);
      final lock = container.read(passcodeLockProvider.notifier);
      final state = container.read(passcodeLockProvider);
      expect(state.loaded, isTrue);
      expect(state.locked, isTrue);
      expect(state.unreadable, isTrue);

      // Nothing opens it, and nothing is written over the real entry.
      expect(await lock.unlock('2580'), UnlockResult.wrong);
      await expectLater(
        lock.setPasscode('1111', iterations: 100),
        throwsStateError,
      );
      await expectLater(lock.turnOff(), throwsStateError);
      await expectLater(lock.setAutoLock(1), throwsStateError);
      expect(storage.writes, 0);
      expect(container.read(passcodeLockProvider).locked, isTrue);

      // Once the keychain answers, the saved passcode is back.
      storage.readFails = false;
      await lock.retryRead();
      expect(container.read(passcodeLockProvider).unreadable, isFalse);
      expect(container.read(passcodeLockProvider).locked, isTrue);
      expect(await lock.unlock('2580'), UnlockResult.unlocked);
    });

    test('a failed write changes nothing', () async {
      final container = await create(await savedWith('2580'));
      final lock = container.read(passcodeLockProvider.notifier);
      await lock.unlock('2580');
      storage.writeFails = true;
      await expectLater(lock.turnOff(), throwsA(isA<PlatformException>()));
      await expectLater(lock.setAutoLock(1), throwsA(isA<PlatformException>()));
      final state = container.read(passcodeLockProvider);
      expect(state.settings.enabled, isTrue);
      expect(state.settings.autoLockMinutes, 5);
    });

    test('wrong passcodes are spaced out after five', () async {
      expect(PasscodeLock.delayAfter(4), Duration.zero);
      expect(PasscodeLock.delayAfter(5), const Duration(seconds: 30));
      expect(PasscodeLock.delayAfter(6), const Duration(seconds: 60));
      expect(PasscodeLock.delayAfter(20), const Duration(hours: 1));

      final container = await create(await savedWith('2580'));
      final lock = container.read(passcodeLockProvider.notifier);
      for (var i = 0; i < 4; i++) {
        expect(await lock.unlock('0000'), UnlockResult.wrong);
        expect(container.read(passcodeLockProvider).retryAt, isNull);
      }
      expect(await lock.unlock('0000'), UnlockResult.wrong);
      expect(
        container.read(passcodeLockProvider).retryAt,
        now.add(const Duration(seconds: 30)),
      );

      // Even the right passcode waits.
      expect(await lock.unlock('2580'), UnlockResult.wait);
      now = now.add(const Duration(seconds: 29));
      expect(await lock.unlock('2580'), UnlockResult.wait);

      now = now.add(const Duration(seconds: 1));
      expect(await lock.unlock('0000'), UnlockResult.wrong);
      expect(
        container.read(passcodeLockProvider).retryAt,
        now.add(const Duration(seconds: 60)),
      );
      now = now.add(const Duration(seconds: 60));
      expect(await lock.unlock('2580'), UnlockResult.unlocked);
      expect(container.read(passcodeLockProvider).failedAttempts, 0);
      expect(container.read(passcodeLockProvider).retryAt, isNull);
    });
  });

  group('lock screen', () {
    late _FlakyStorage storage;

    Future<ProviderContainer> pump(
      WidgetTester tester, {
      Future<void> Function()? logOut,
    }) async {
      final saved = await tester.runAsync(
        () async => PasscodeSettings(
          hash: await PasscodeHash.create('2580', iterations: 100),
          autoLockMinutes: 15,
        ).toJson(),
      );
      storage = _FlakyStorage(saved);
      final container = ProviderContainer(
        overrides: [
          passcodeStorageProvider.overrideWithValue(storage),
          if (logOut != null) passcodeLogOutProvider.overrideWithValue(logOut),
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

    Future<void> forgot(WidgetTester tester) async {
      await tester.tap(find.text('Forgot passcode?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a forgotten passcode goes only after logging out', (
      tester,
    ) async {
      late ProviderContainer container;
      final seen = <String>[];
      container = await pump(
        tester,
        logOut: () async {
          // While logging out the window stays locked over a passcode
          // still saved.
          final state = container.read(passcodeLockProvider);
          seen.add('logOut locked=${state.locked}');
          seen.add('saved=${PasscodeSettings.fromJson(storage.saved).enabled}');
        },
      );
      await forgot(tester);
      expect(seen, ['logOut locked=true', 'saved=true']);
      expect(PasscodeSettings.fromJson(storage.saved).enabled, isFalse);
      expect(PasscodeSettings.fromJson(storage.saved).autoLockMinutes, 15);
      expect(find.text('Mollygram is locked'), findsNothing);
      await finish(tester, container);
    });

    testWidgets('a failed log out leaves the passcode', (tester) async {
      final container = await pump(
        tester,
        logOut: () async => throw StateError('offline'),
      );
      await forgot(tester);
      expect(
        find.text("Couldn't log out. The passcode stays until you can."),
        findsOneWidget,
      );
      expect(find.text('Mollygram is locked'), findsOneWidget);
      expect(PasscodeSettings.fromJson(storage.saved).enabled, isTrue);
      await finish(tester, container);
    });

    testWidgets('without a session the passcode stays', (tester) async {
      final container = await pump(
        tester,
        logOut: () async => throw const NoSessionToLogOut(),
      );
      await forgot(tester);
      expect(find.textContaining("Telegram couldn't start"), findsOneWidget);
      expect(find.text('Mollygram is locked'), findsOneWidget);
      expect(PasscodeSettings.fromJson(storage.saved).enabled, isTrue);
      await finish(tester, container);
    });

    testWidgets('after five wrong passcodes it asks to wait', (tester) async {
      final container = await pump(tester);
      for (var i = 0; i < 5; i++) {
        await enter(tester, '1111');
      }
      expect(find.textContaining('Too many tries'), findsOneWidget);
      // The field takes nothing until the wait is over.
      final field = tester.widget<MgUnderlineField>(
        find.byKey(const ValueKey('passcodeField')),
      );
      expect(field.enabled, isFalse);
      await finish(tester, container);
    });
  });

  test('notifications show no text while locked', () {
    const settings = NotificationSettings();
    expect(settings.showPreview, isTrue);
    expect(
      notificationSettingsUnder(
        settings,
        const PasscodeState(loaded: true, locked: true),
      ).showPreview,
      isFalse,
    );
    expect(
      notificationSettingsUnder(settings, const PasscodeState()).showPreview,
      isFalse,
    );
    expect(
      notificationSettingsUnder(
        settings,
        const PasscodeState(loaded: true),
      ).showPreview,
      isTrue,
    );
  });
}
