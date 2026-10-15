import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/commands/command_registry.dart';
import 'package:mollygram/src/commands/shortcut_key.dart';
import 'package:mollygram/src/settings/preferences.dart';
import 'package:mollygram/src/settings/settings_window.dart';
import 'package:mollygram/src/settings/shortcuts/key_caps.dart';
import 'package:mollygram/src/settings/shortcuts/shortcuts_page.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

const _k = LogicalKeyboardKey.keyK;
const _cmdK = ShortcutKey(_k, meta: true);
const _cmdT = ShortcutKey(LogicalKeyboardKey.keyT, meta: true);
const _cmdJ = ShortcutKey(LogicalKeyboardKey.keyJ, meta: true);

void main() {
  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  void onMac() {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);
  }

  PaletteCommand command(String id, [ShortcutKey? key]) =>
      PaletteCommand(id: id, title: id, shortcut: key?.activator, run: () {});

  group('ShortcutKey', () {
    onMac();
    test('writes and reads itself', () {
      const key = ShortcutKey(_k, meta: true, shift: true, alt: true);
      expect(key.encode(), 'meta+alt+shift+${_k.keyId}');
      expect(ShortcutKey.decode(key.encode()), key);
      expect(ShortcutKey.decode('hyper+107'), isNull);
      expect(ShortcutKey.decode('meta+'), isNull);
      expect(ShortcutKey.decode(42), isNull);
    });

    test('shows mac key caps in menu order', () {
      const key = ShortcutKey(_k, meta: true, shift: true, control: true);
      expect(key.caps, ['⌃', '⇧', '⌘', 'K']);
      expect(key.label, '⌃⇧⌘K');
      expect(ShortcutKey.primary(LogicalKeyboardKey.comma).label, '⌘,');
    });
  });

  group('recorder', () {
    onMac();
    test('waits through modifiers and reads the key', () {
      expect(
        recordKey(LogicalKeyboardKey.metaLeft, meta: true),
        isA<RecordingContinues>(),
      );
      expect(
        (recordKey(_k, meta: true, shift: true) as RecordingDone).key,
        const ShortcutKey(_k, meta: true, shift: true),
      );
    });

    test('Esc cancels, Delete clears, a bare letter needs a modifier', () {
      expect(recordKey(LogicalKeyboardKey.escape), isA<RecordingCancelled>());
      expect(recordKey(LogicalKeyboardKey.backspace), isA<RecordingCleared>());
      expect(recordKey(LogicalKeyboardKey.delete), isA<RecordingCleared>());
      expect(recordKey(_k), isA<RecordingNeedsModifier>());
      expect(recordKey(_k, shift: true), isA<RecordingNeedsModifier>());
      expect(recordKey(LogicalKeyboardKey.f5), isA<RecordingDone>());
      // With a modifier, Esc and Delete are shortcuts like any other.
      expect(
        recordKey(LogicalKeyboardKey.backspace, meta: true),
        isA<RecordingDone>(),
      );
    });
  });

  group('manifest and system keys', () {
    onMac();

    test('reads keys as plugin manifests write them', () {
      expect(
        ShortcutKey.parse('Mod+Shift+S'),
        const ShortcutKey(LogicalKeyboardKey.keyS, meta: true, shift: true),
      );
      expect(
        ShortcutKey.parse('Ctrl+Alt+P'),
        const ShortcutKey(LogicalKeyboardKey.keyP, control: true, alt: true),
      );
      expect(
        ShortcutKey.parse('⌥⌘K'),
        const ShortcutKey(_k, meta: true, alt: true),
      );
      expect(ShortcutKey.parse('Cmd+,')?.label, '⌘,');
      expect(ShortcutKey.parse('Cmd+F5')?.key, LogicalKeyboardKey.f5);
      expect(ShortcutKey.parse('Cmd+Enter')?.key, LogicalKeyboardKey.enter);
      expect(ShortcutKey.parse('Hyper+K'), isNull);
      expect(ShortcutKey.parse('Cmd+'), isNull);
      expect(ShortcutKey.parse('Cmd+Ж'), isNull);
    });

    test('knows the keys macOS keeps', () {
      expect(
        isReservedShortcut(
          const ShortcutKey(LogicalKeyboardKey.keyQ, meta: true),
        ),
        isTrue,
      );
      expect(
        isReservedShortcut(
          const ShortcutKey(LogicalKeyboardKey.space, meta: true),
        ),
        isTrue,
      );
      expect(
        isReservedShortcut(
          const ShortcutKey(LogicalKeyboardKey.keyQ, meta: true, shift: true),
        ),
        isFalse,
      );
      expect(isReservedShortcut(_cmdK), isFalse);
    });
  });

  group('registry keys', () {
    onMac();
    late CommandRegistry registry;

    setUp(() => registry = CommandRegistry());
    tearDown(() => registry.dispose());

    test('the user\'s key replaces the default everywhere', () {
      registry.register('app', () => [command('app.a', _cmdK)]);
      var notified = 0;
      registry
        ..addListener(() => notified++)
        ..overrides = {'app.a': _cmdJ};
      expect(notified, 1);
      expect(registry.effectiveKeys()['app.a'], _cmdJ);
      expect(ShortcutKey.of(registry.commands.single.shortcut!), _cmdJ);
      // The same keys again change nothing.
      registry.overrides = {'app.a': _cmdJ};
      expect(notified, 1);
      registry.overrides = {'app.a': null};
      expect(registry.commands.single.shortcut, isNull);
    });

    test('a default already in use is dropped, app before shell', () {
      registry
        ..register('shell', () => [command('shell.t', _cmdT)])
        ..register('app', () => [command('app.t', _cmdT)])
        ..register('plugins', () => [command('plugin.x.k', _cmdK)])
        ..registerShortcuts(
          'shell',
          () => [
            ShortcutAction(
              id: 'shell.k',
              title: 'k',
              shortcut: _cmdK.activator,
            ),
          ],
        );
      final keys = registry.effectiveKeys();
      expect(keys['app.t'], _cmdT);
      expect(keys['shell.t'], isNull);
      expect(keys['shell.k'], _cmdK);
      expect(keys['plugin.x.k'], isNull, reason: 'plugins come last');
      expect(registry.whoUses(_cmdT), 'app.t');
      expect(registry.whoUses(_cmdT, except: 'app.t'), isNull);
    });

    test('a key the user took is no one else\'s default', () {
      registry
        ..register('app', () => [command('app.a', _cmdK), command('app.b')])
        ..overrides = {'app.b': _cmdK};
      expect(registry.effectiveKeys(), {'app.a': null, 'app.b': _cmdK});
      expect(registry.whoUses(_cmdK), 'app.b');
    });

    test('accounts get ⌃⌘1…⌃⌘3, tabs keep ⌘1…⌘9', () {
      registry
        ..registerShortcuts(
          'shell',
          () => shellShortcutActions(ShellStrings.en),
        )
        ..register('app', () => [command('app.account.1')]);
      final keys = registry.effectiveKeys();
      const account1 = ShortcutKey(
        LogicalKeyboardKey.digit1,
        meta: true,
        control: true,
      );
      expect(keys['app.account.1'], account1);
      expect(account1.label, '⌃⌘1');
      expect(
        keys['shell.tab.1'],
        ShortcutKey.primary(LogicalKeyboardKey.digit1),
      );
      expect(
        keys['shell.tab.2'],
        ShortcutKey.primary(LogicalKeyboardKey.digit2),
      );
      expect(ShortcutKey.of(registry.commands.single.shortcut!), account1);
    });

    test('closing split view shares the key of opening it', () {
      registry
        ..registerShortcuts(
          'shell',
          () => shellShortcutActions(ShellStrings.en),
        )
        ..register('shell', () => [command('shell.closeSplit', _cmdK)])
        ..overrides = {'shell.split': _cmdJ};
      expect(ShortcutKey.of(registry.commands.single.shortcut!), _cmdJ);
      expect([
        for (final a in registry.actions) a.id,
      ], isNot(contains('shell.closeSplit')));
    });

    test('a key given to an action that is not loaded stays taken', () {
      registry
        ..overrides = {'plugin.x.y': _cmdK}
        ..register('app', () => [command('app.a', _cmdK)]);
      expect(registry.effectiveKeys()['app.a'], isNull);
      expect(registry.whoUses(_cmdK), 'plugin.x.y');
      registry.register('plugins', () => [command('plugin.x.y')]);
      expect(registry.effectiveKeys()['plugin.x.y'], _cmdK);
      expect(registry.effectiveKeys()['app.a'], isNull);
    });

    test('a source added later is announced after the build', () async {
      var notified = 0;
      registry
        ..addListener(() => notified++)
        ..register('app', () => [command('app.a', _cmdK)])
        ..register('plugins', () => [command('plugin.x.y')]);
      expect(notified, 0);
      await Future<void>.delayed(Duration.zero);
      expect(notified, 1, reason: 'one notice for both');
      expect(registry.effectiveKeys()['app.a'], _cmdK);
      registry.unregister('plugins');
      await Future<void>.delayed(Duration.zero);
      expect(notified, 2);
      expect(registry.effectiveKeys().keys, ['app.a']);
    });

    test('overrides go to the preferences and back', () {
      final saved = encodeShortcutOverrides({'a': _cmdK, 'b': null});
      final restored = Preferences.fromJson(
        const Preferences().copyWith(shortcuts: saved).toJson(),
      );
      expect(decodeShortcutOverrides(restored.shortcuts), {
        'a': _cmdK,
        'b': null,
      });
      expect(
        Preferences.fromJson({
          'shortcuts': {'a': 3, 'b': 'nonsense', 4: 'x'},
        }).shortcuts,
        {'b': 'nonsense'},
      );
      expect(decodeShortcutOverrides({'b': 'nonsense'}), isEmpty);
    });

    test('the provider follows the preferences', () {
      final container = ProviderContainer(
        overrides: [
          preferencesStorageProvider.overrideWithValue(
            MemoryPreferencesStorage(),
          ),
          initialPreferencesProvider.overrideWithValue(
            Preferences(shortcuts: {'app.a': _cmdJ.encode()}),
          ),
        ],
      );
      addTearDown(container.dispose);
      final registry = container.read(commandRegistryProvider);
      expect(registry.overrides, {'app.a': _cmdJ});
      container
          .read(preferencesProvider.notifier)
          .update((p) => p.copyWith(shortcuts: const {}));
      expect(registry.overrides, isEmpty);
    });
  });

  group('page', () {
    late ProviderContainer container;
    late CommandRegistry registry;

    Future<void> pump(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(900, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      container = ProviderContainer(
        overrides: [
          preferencesStorageProvider.overrideWithValue(
            MemoryPreferencesStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);
      registry = container.read(commandRegistryProvider)
        ..register(
          'app',
          () => [
            PaletteCommand(
              id: 'app.settings',
              title: 'Settings',
              shortcut: ShortcutKey.primary(LogicalKeyboardKey.comma).activator,
              run: () {},
            ),
            command('app.contacts'),
          ],
        )
        ..registerShortcuts(
          'shell',
          () => shellShortcutActions(ShellStrings.en),
        );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildMgTheme(MgColors.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Material(child: ShortcutsPage()),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> press(
      WidgetTester tester,
      LogicalKeyboardKey key, {
      bool meta = false,
      bool shift = false,
    }) async {
      if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> record(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(ValueKey(('recordShortcut', id))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShortcutRecorder), findsOneWidget);
    }

    List<String> saved() => [
      for (final MapEntry(:key, :value)
          in container.read(preferencesProvider).shortcuts.entries)
        '$key=${ShortcutKey.decode(value)?.label}',
    ];

    testWidgets('lists the actions in groups with their keys', variant: mac, (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('App'), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Go to tab 9'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is KeyCaps && w.shortcut.label == '⌘,'),
        findsOneWidget,
      );
      expect(find.text('None'), findsWidgets);
    });

    testWidgets('records a new key and applies it', variant: mac, (
      tester,
    ) async {
      await pump(tester);
      await record(tester, 'app.contacts');
      await press(tester, LogicalKeyboardKey.keyY);
      expect(find.text('Add ⌘, ⌃ or ⌥ to the key'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.keyY, meta: true, shift: true);
      expect(saved(), ['app.contacts=⇧⌘Y']);
      expect(
        ShortcutKey.of(registry.commandsOf('app').last.shortcut!).label,
        '⇧⌘Y',
      );
      expect(
        find.byKey(const ValueKey(('restoreShortcut', 'app.contacts'))),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey(('restoreShortcut', 'app.contacts'))),
      );
      await tester.pump();
      expect(saved(), isEmpty);
      // The preferences are written a moment later.
      await tester.pump(PreferencesNotifier.saveDelay);
    });

    testWidgets('Esc cancels and Delete clears', variant: mac, (tester) async {
      await pump(tester);
      await record(tester, 'app.settings');
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ShortcutRecorder), findsNothing);
      expect(saved(), isEmpty);

      await record(tester, 'app.settings');
      await press(tester, LogicalKeyboardKey.backspace);
      expect(saved(), ['app.settings=null']);
      expect(registry.effectiveKeys()['app.settings'], isNull);
      // The preferences are written a moment later.
      await tester.pump(PreferencesNotifier.saveDelay);
    });

    testWidgets('a key in use asks before it moves', variant: mac, (
      tester,
    ) async {
      await pump(tester);
      await record(tester, 'app.contacts');
      await press(tester, LogicalKeyboardKey.keyT, meta: true);
      expect(find.text('Already used by “New tab”'), findsOneWidget);
      expect(saved(), isEmpty);

      await tester.tap(find.byKey(const ValueKey('replaceShortcut')));
      await tester.pump();
      expect(saved(), ['shell.newTab=null', 'app.contacts=⌘T']);
      expect(registry.whoUses(_cmdT), 'app.contacts');
      // The preferences are written a moment later.
      await tester.pump(PreferencesNotifier.saveDelay);
    });

    testWidgets('restores every default', variant: mac, (tester) async {
      await pump(tester);
      registry.overrides = {'app.settings': null};
      container
          .read(preferencesProvider.notifier)
          .update((p) => p.copyWith(shortcuts: const {'app.settings': null}));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('restoreAllShortcuts')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Restore'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(saved(), isEmpty);
      expect(registry.overrides, isEmpty);
      // The preferences are written a moment later.
      await tester.pump(PreferencesNotifier.saveDelay);
    });

    testWidgets('records while the search field has focus', variant: mac, (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await record(tester, 'app.contacts');
      await press(tester, LogicalKeyboardKey.keyY, meta: true);
      expect(saved(), ['app.contacts=⌘Y']);
      expect(find.byType(ShortcutRecorder), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
      await tester.pump(PreferencesNotifier.saveDelay);
    });

    testWidgets(
      'refuses keys the system keeps and stops on a click outside',
      variant: mac,
      (tester) async {
        await pump(tester);
        await record(tester, 'app.contacts');
        await press(tester, LogicalKeyboardKey.keyQ, meta: true);
        expect(find.text('Used by macOS'), findsOneWidget);
        expect(find.byType(ShortcutRecorder), findsOneWidget);
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(ShortcutRecorder), findsNothing);
        expect(saved(), isEmpty);
      },
    );

    testWidgets(
      'restoring a default someone else took asks first',
      variant: mac,
      (tester) async {
        await pump(tester);
        final comma = ShortcutKey.primary(LogicalKeyboardKey.comma);
        registry.overrides = {'app.settings': _cmdJ, 'app.contacts': comma};
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(
          find.byKey(const ValueKey(('restoreShortcut', 'app.settings'))),
        );
        await tester.pump();
        expect(find.text('Already used by “app.contacts”'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const ValueKey('replaceShortcut')));
        await tester.pump();
        expect(saved(), isEmpty);
        expect(registry.effectiveKeys()['app.settings'], comma);
        expect(registry.effectiveKeys()['app.contacts'], isNull);
        await tester.pump(PreferencesNotifier.saveDelay);
      },
    );

    testWidgets('searches titles and keys', variant: mac, (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'tab 3');
      await tester.pump();
      expect(find.text('Go to tab 3'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      await tester.enterText(find.byType(TextField), '⌘,');
      await tester.pump();
      expect(find.text('Settings'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Nothing found'), findsOneWidget);
    });
  });

  test('the section is in the settings', () {
    expect([for (final s in settingsSections) s.id], contains('shortcuts'));
  });

  test('groups by owner and id', () {
    BindableAction a(String id, String owner) =>
        BindableAction(id: id, owner: owner, title: id);
    expect(shortcutGroupOf(a('app.account.2', 'app')), ShortcutGroup.accounts);
    expect(
      shortcutGroupOf(a('shell.newTab', 'shell')),
      ShortcutGroup.navigation,
    );
    expect(shortcutGroupOf(a('plugin.x.y', 'plugins')), ShortcutGroup.plugins);
    expect(shortcutGroupOf(a('chat.reply', 'chat')), ShortcutGroup.chat);
    expect(shortcutGroupOf(a('app.settings', 'app')), ShortcutGroup.app);
  });
}
