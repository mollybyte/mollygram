import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/commands/command_registry.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

void main() {
  late CommandRegistry registry;
  late List<String> ran;

  PaletteCommand command(
    String id, {
    String? title,
    SingleActivator? shortcut,
  }) => PaletteCommand(
    id: id,
    title: title ?? id,
    shortcut: shortcut,
    run: () => ran.add(id),
  );

  setUp(() {
    registry = CommandRegistry();
    ran = [];
  });

  test('lists commands in the order owners registered', () {
    registry
      ..register('app', () => [command('app.a'), command('app.b')])
      ..register('shell', () => [command('shell.c')]);
    expect(
      [for (final c in registry.commands) c.id],
      ['app.a', 'app.b', 'shell.c'],
    );
    expect([for (final c in registry.commandsOf('shell')) c.id], ['shell.c']);
    expect(registry.commandsOf('nobody'), isEmpty);
  });

  test('the first owner of an id wins', () {
    registry
      ..register('app', () => [command('same', title: 'App')])
      ..register(
        'plugin',
        () => [command('same', title: 'Plugin'), command('plugin.x')],
      );
    expect([for (final c in registry.commands) c.title], ['App', 'plugin.x']);
    expect(registry.find('same')?.title, 'App');
  });

  test('builds commands from the current state', () {
    var split = false;
    registry.register(
      'shell',
      () => [command(split ? 'shell.closeSplit' : 'shell.split')],
    );
    expect(registry.find('shell.split'), isNotNull);
    split = true;
    expect(registry.find('shell.split'), isNull);
    expect(registry.find('shell.closeSplit'), isNotNull);
  });

  test('runs a command by id', () {
    registry.register('app', () => [command('app.settings')]);
    expect(registry.run('app.settings'), isTrue);
    expect(registry.run('app.missing'), isFalse);
    expect(ran, ['app.settings']);
  });

  test('registering again replaces the owner', () {
    registry
      ..register('app', () => [command('old')])
      ..register('app', () => [command('new')]);
    expect([for (final c in registry.commands) c.id], ['new']);
  });

  test('unregisters only the source that is still registered', () {
    List<PaletteCommand> first() => [command('first')];
    List<PaletteCommand> second() => [command('second')];
    registry
      ..register('app', first)
      ..register('app', second)
      ..unregister('app', first);
    expect([for (final c in registry.commands) c.id], ['second']);
    registry.unregister('app');
    expect(registry.commands, isEmpty);
  });

  test('binds the shortcuts of one owner', () {
    final key = SingleActivator(LogicalKeyboardKey.comma, meta: true);
    registry
      ..register('app', () => [command('app.a', shortcut: key)])
      ..register(
        'shell',
        () => [
          command(
            'shell.b',
            shortcut: const SingleActivator(LogicalKeyboardKey.keyT),
          ),
        ],
      );
    final bindings = registry.shortcutsOf('app');
    expect(bindings.keys, [key]);
    bindings[key]!();
    expect(ran, ['app.a']);
  });
}
