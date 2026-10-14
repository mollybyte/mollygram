import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

void main() {
  group('PaletteQuery', () {
    test('prefixes pick the mode', () {
      expect(PaletteQuery.parse(''), const PaletteQuery(PaletteMode.all, ''));
      expect(
        PaletteQuery.parse('> split'),
        const PaletteQuery(PaletteMode.commands, 'split'),
      );
      expect(
        PaletteQuery.parse('@ann'),
        const PaletteQuery(PaletteMode.people, 'ann'),
      );
      expect(
        PaletteQuery.parse('  #lease '),
        const PaletteQuery(PaletteMode.messages, 'lease'),
      );
      expect(
        PaletteQuery.parse('anna'),
        const PaletteQuery(PaletteMode.all, 'anna'),
      );
    });
  });

  group('PaletteSearch', () {
    final commands = [
      PaletteCommand(id: 'a', title: 'New tab', run: () {}),
      PaletteCommand(
        id: 'b',
        title: 'Open second chat in split view',
        keywords: const ['Открыть второй чат в сплите'],
        run: () {},
      ),
      PaletteCommand(id: 'c', title: 'Close tab', run: () {}),
      PaletteCommand(id: 'd', title: 'Tabulate', run: () {}),
    ];
    final search = PaletteSearch(
      directory: MockChatDirectory(),
      commands: commands,
    );

    List<PaletteGroupKind> kinds(List<PaletteGroup> g) => [
      for (final x in g) x.kind,
    ];

    test('empty query shows recent chats and commands', () async {
      final g = await search.run(PaletteQuery.parse(''));
      expect(kinds(g), [PaletteGroupKind.recent, PaletteGroupKind.commands]);
    });

    test('text searches chats, commands and messages', () async {
      final g = await search.run(PaletteQuery.parse('ann'));
      expect(kinds(g), [PaletteGroupKind.chats]);
      final board = await search.run(PaletteQuery.parse('board'));
      expect(kinds(board), [PaletteGroupKind.messages]);
    });

    test('> lists only commands, best match first', () async {
      final g = await search.run(PaletteQuery.parse('>tab'));
      expect(kinds(g), [PaletteGroupKind.commands]);
      final ids = [
        for (final i in g.single.items) (i as CommandPaletteItem).command.id,
      ];
      expect(ids, ['d', 'a', 'c']);
    });

    test('commands match keywords in the other language', () async {
      final g = await search.run(PaletteQuery.parse('>сплит'));
      expect((g.single.items.single as CommandPaletteItem).command.id, 'b');
    });

    test('@ lists people, recent ones when empty', () async {
      final empty = await search.run(PaletteQuery.parse('@'));
      expect(kinds(empty), [PaletteGroupKind.people]);
      final g = await search.run(PaletteQuery.parse('@vstone'));
      expect(
        (g.single.items.single as ChatPaletteItem).chat.title,
        'Vicky Stone',
      );
    });

    test('# searches messages only', () async {
      expect(await search.run(PaletteQuery.parse('#')), isEmpty);
      final g = await search.run(PaletteQuery.parse('#lease'));
      expect(kinds(g), [PaletteGroupKind.messages]);
    });
  });

  group('ChatSummary.initials', () {
    String ini(String t) => ChatSummary(id: 0, title: t).initials;

    test('two words, one word, non-latin, symbols', () {
      expect(ini('Anna Morris'), 'AM');
      expect(ini('dad'), 'D');
      expect(ini('Аня Морозова'), 'АМ');
      expect(ini('— Product team'), 'PT');
      expect(ini('  '), '');
    });
  });

  test('Russian plural for new messages', () {
    final ru = ShellStrings.ru;
    expect(ru.newMessages(1), '1 новое');
    expect(ru.newMessages(3), '3 новых');
    expect(ru.newMessages(11), '11 новых');
    expect(ru.newMessages(21), '21 новое');
    expect(ShellStrings.en.newMessages(3), '3 new');
  });
}
