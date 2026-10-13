import 'package:flutter/widgets.dart';

import '../data/chat_directory.dart';

/// What the palette searches, picked by the first character of the query.
enum PaletteMode {
  /// No prefix: recent chats and commands, or everything once you type.
  all,

  /// `>`: commands only.
  commands,

  /// `@`: people and chats.
  people,

  /// `#`: messages.
  messages,
}

/// A parsed palette query. Prefixes are the same in every UI language.
@immutable
class PaletteQuery {
  const PaletteQuery(this.mode, this.text);

  factory PaletteQuery.parse(String raw) {
    final trimmed = raw.trimLeft();
    if (trimmed.isEmpty) return const PaletteQuery(PaletteMode.all, '');
    final mode = switch (trimmed[0]) {
      '>' => PaletteMode.commands,
      '@' => PaletteMode.people,
      '#' => PaletteMode.messages,
      _ => PaletteMode.all,
    };
    final text = mode == PaletteMode.all ? trimmed : trimmed.substring(1);
    return PaletteQuery(mode, text.trim());
  }

  final PaletteMode mode;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is PaletteQuery && other.mode == mode && other.text == text;

  @override
  int get hashCode => Object.hash(mode, text);
}

/// A built-in glyph for commands; plugins will bring their own icons later.
enum PaletteGlyph { tab, closeTab, split, swap, next, previous, generic }

/// An action the palette can run.
@immutable
class PaletteCommand {
  const PaletteCommand({
    required this.id,
    required this.title,
    required this.run,
    this.subtitle,
    this.shortcut,
    this.glyph = PaletteGlyph.generic,
    this.keywords = const [],
  });

  /// Stable id, for example `shell.newTab` or `plugin.translator.draft`.
  final String id;
  final String title;

  /// Where the command comes from, such as a plugin name.
  final String? subtitle;
  final SingleActivator? shortcut;
  final PaletteGlyph glyph;

  /// Extra words to match, such as the title in the other UI language.
  final List<String> keywords;
  final VoidCallback run;
}

sealed class PaletteItem {
  const PaletteItem();
}

class ChatPaletteItem extends PaletteItem {
  const ChatPaletteItem(this.chat);
  final ChatSummary chat;
}

class MessagePaletteItem extends PaletteItem {
  const MessagePaletteItem(this.message);
  final MessageHit message;
}

class CommandPaletteItem extends PaletteItem {
  const CommandPaletteItem(this.command);
  final PaletteCommand command;
}

enum PaletteGroupKind { recent, chats, people, messages, commands }

@immutable
class PaletteGroup {
  const PaletteGroup(this.kind, this.items);
  final PaletteGroupKind kind;
  final List<PaletteItem> items;
}

/// Turns a query into grouped results. Pure apart from the directory calls,
/// so it is tested without widgets.
class PaletteSearch {
  PaletteSearch({required this.directory, required this.commands});

  final ChatDirectory directory;
  final List<PaletteCommand> commands;

  /// How many commands the empty palette suggests.
  static const int suggestedCommands = 6;

  /// Results that need no directory search: the empty palette, `>`
  /// commands, `@` with no text and `#` with no text. Returns `null` when
  /// [run] has to search, so the palette can show the first frame complete.
  List<PaletteGroup>? runSync(PaletteQuery query) {
    final text = query.text;
    return switch (query.mode) {
      PaletteMode.all when text.isEmpty => _groups([
        (
          PaletteGroupKind.recent,
          [for (final c in directory.recentChats()) ChatPaletteItem(c)],
        ),
        (
          PaletteGroupKind.commands,
          [
            for (final c in commands.take(suggestedCommands))
              CommandPaletteItem(c),
          ],
        ),
      ]),
      PaletteMode.commands => _groups([
        (
          PaletteGroupKind.commands,
          [for (final c in matchCommands(text)) CommandPaletteItem(c)],
        ),
      ]),
      PaletteMode.people when text.isEmpty => _groups([
        (
          PaletteGroupKind.people,
          [for (final c in directory.recentChats()) ChatPaletteItem(c)],
        ),
      ]),
      PaletteMode.messages when text.isEmpty => const [],
      _ => null,
    };
  }

  Future<List<PaletteGroup>> run(PaletteQuery query) async {
    final ready = runSync(query);
    if (ready != null) return ready;
    final text = query.text;
    if (query.mode == PaletteMode.people) {
      return _groups([
        (
          PaletteGroupKind.people,
          [
            for (final c in await directory.searchChats(text))
              ChatPaletteItem(c),
          ],
        ),
      ]);
    }
    if (query.mode == PaletteMode.messages) {
      return _groups([
        (
          PaletteGroupKind.messages,
          [
            for (final m in await directory.searchMessages(text))
              MessagePaletteItem(m),
          ],
        ),
      ]);
    }
    // Both searches run at once.
    final chats = directory.searchChats(text);
    final messages = directory.searchMessages(text);
    return _groups([
      (
        PaletteGroupKind.chats,
        [for (final c in await chats) ChatPaletteItem(c)],
      ),
      (
        PaletteGroupKind.commands,
        [for (final c in matchCommands(text)) CommandPaletteItem(c)],
      ),
      (
        PaletteGroupKind.messages,
        [for (final m in await messages) MessagePaletteItem(m)],
      ),
    ]);
  }

  static List<PaletteGroup> _groups(
    List<(PaletteGroupKind, List<PaletteItem>)> parts,
  ) => [
    for (final (kind, items) in parts)
      if (items.isNotEmpty) PaletteGroup(kind, items),
  ];

  /// Commands matching [text], best first: title prefix, then a word start,
  /// then anywhere in the title or keywords.
  List<PaletteCommand> matchCommands(String text) {
    if (text.isEmpty) return commands;
    final q = text.toLowerCase();
    final scored = <(int, int, PaletteCommand)>[];
    for (var i = 0; i < commands.length; i++) {
      final c = commands[i];
      final score = _score(c, q);
      if (score > 0) scored.add((score, i, c));
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
    });
    return [for (final s in scored) s.$3];
  }

  static int _score(PaletteCommand c, String q) {
    final title = c.title.toLowerCase();
    if (title.startsWith(q)) return 4;
    if (title.split(' ').any((w) => w.startsWith(q))) return 3;
    if (title.contains(q)) return 2;
    final rest = [c.subtitle ?? '', ...c.keywords].join(' ').toLowerCase();
    return rest.contains(q) ? 1 : 0;
  }
}
