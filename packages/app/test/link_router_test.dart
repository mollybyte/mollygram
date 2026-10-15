import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/links/link_router.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart'
    show PaletteMode, PaletteQuery;

void main() {
  late Map<String, LinkTarget?> targets;
  late List<String> log;
  late _Presenter presenter;
  late LinkRouter router;
  late Set<String> commands;
  late _CommandChats chats;
  Object? resolveError;

  setUp(() {
    targets = {};
    log = [];
    commands = {'app.settings'};
    resolveError = null;
    chats = _CommandChats(log);
    presenter = _Presenter(log);
    router = LinkRouter(
      resolve: (raw) async {
        if (resolveError case final error?) throw error;
        return targets[raw];
      },
      join: (preview) async {
        log.add('join ${preview.title}');
        return const ChatJoined(42);
      },
      openChat: (id) => log.add('chat $id'),
      openMessage: (chat, message) => log.add('message $chat/$message'),
      runCommand: (id) {
        log.add('command $id');
        return commands.contains(id);
      },
      launch: (uri) async {
        log.add('launch $uri');
        return true;
      },
      search: (query) => log.add('search $query'),
      commandChats: chats,
    )..presenter = presenter;
  });

  test('searches hashtags with their own sign', () {
    router
      ..searchHashtag('#news')
      ..searchHashtag(r'$TON');
    expect(log, ['search ##news', r'search #$TON']);
    // The first "#" switches the search to messages; the hashtag stays.
    expect(
      PaletteQuery.parse('##news'),
      const PaletteQuery(PaletteMode.messages, '#news'),
    );
  });

  test('sends a bot command to the chat it was tapped in', () async {
    await router.sendBotCommand('/start', chatId: 7, senderUserId: 5);
    expect(log, ['send 7 /start']);
  });

  test('names the bot of a bare command in a group', () async {
    chats
      ..groups.add(7)
      ..bots[5] = 'somebot';
    await router.sendBotCommand('/start', chatId: 7, senderUserId: 5);
    await router.sendBotCommand('/help@other', chatId: 7, senderUserId: 5);
    await router.sendBotCommand('/stop', chatId: 7, senderUserId: 6);
    expect(log, [
      'send 7 /start@somebot',
      'send 7 /help@other',
      'send 7 /stop',
    ]);
  });

  test('does not send a command where the user cannot write', () async {
    chats.readOnly.add(7);
    await router.sendBotCommand('/start', chatId: 7);
    expect(log, ['notice cannotSend']);
  });

  test('tells the user when a command fails to send', () async {
    chats.failing = true;
    await router.sendBotCommand('/start', chatId: 7);
    expect(log, ['notice cannotSend']);
  });

  test('opens other sites in the browser', () async {
    targets['example.com'] = ExternalLinkTarget(
      Uri.parse('https://example.com'),
    );
    await router.open('example.com');
    expect(log, ['launch https://example.com']);
  });

  test('opens chats and messages in the workspace', () async {
    targets['@anna'] = const ChatLinkTarget(3);
    targets['t.me/c/1/2'] = const ChatLinkTarget(5, messageId: 2);
    await router.open('@anna');
    await router.open('t.me/c/1/2');
    expect(log, ['chat 3', 'message 5/2']);
  });

  test('opens the joined chat after the sheet', () async {
    const preview = ChatJoinPreview(title: 'News', isChannel: true);
    targets['t.me/news'] = const JoinLinkTarget(preview);
    presenter.answer = (join) async => switch (await join()) {
      ChatJoined(:final chatId) => chatId,
      _ => null,
    };
    await router.open('t.me/news');
    expect(log, ['sheet News', 'join News', 'chat 42']);
  });

  test('opens nothing when the sheet is cancelled', () async {
    targets['t.me/+x'] = const JoinLinkTarget(
      ChatJoinPreview(title: 'Club', isChannel: false, inviteLink: 'x'),
    );
    presenter.answer = (_) async => null;
    await router.open('t.me/+x');
    expect(log, ['sheet Club']);
  });

  test('without a window, previews a public chat and skips invites', () async {
    router.presenter = null;
    targets['t.me/news'] = const JoinLinkTarget(
      ChatJoinPreview(title: 'News', isChannel: true, chatId: 8),
    );
    targets['t.me/+x'] = const JoinLinkTarget(
      ChatJoinPreview(title: 'Club', isChannel: false, inviteLink: 'x'),
    );
    await router.open('t.me/news');
    await router.open('t.me/+x');
    expect(log, ['chat 8']);
  });

  test('runs commands and says when there is none', () async {
    targets['tg://settings'] = const CommandLinkTarget('app.settings');
    targets['tg://other'] = const CommandLinkTarget('app.other');
    await router.open('tg://settings');
    await router.open('tg://other');
    expect(log, [
      'command app.settings',
      'command app.other',
      'notice unsupported',
    ]);
  });

  test('explains missing and unsupported links', () async {
    targets['t.me/nobody'] = const MissingLinkTarget();
    targets['t.me/club'] = const ForbiddenLinkTarget();
    targets['tg://addstickers'] = const UnsupportedLinkTarget();
    targets['t.me/addstickers/x'] = UnsupportedLinkTarget(
      webFallback: Uri.parse('https://t.me/addstickers/x'),
    );
    await router.open('t.me/nobody');
    await router.open('t.me/club');
    await router.open('tg://addstickers');
    await router.open('t.me/addstickers/x');
    expect(log, [
      'notice missing',
      'notice forbidden',
      'notice unsupported',
      'launch https://t.me/addstickers/x',
    ]);
  });

  test('ignores text that is not a link', () async {
    await router.open('just words');
    expect(log, isEmpty);
  });

  test('falls back to the browser when TDLib fails', () async {
    resolveError = StateError('closed');
    await router.open('t.me/durov');
    await router.open('tg://resolve?domain=durov');
    expect(log, ['launch https://t.me/durov']);
  });

  test('only the latest click acts', () async {
    final router = LinkRouter(
      resolve: (raw) async {
        if (raw == 'slow') {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return const ChatLinkTarget(1);
        }
        return const ChatLinkTarget(2);
      },
      join: (_) async => const JoinRequestSent(),
      openChat: (id) => log.add('chat $id'),
      runCommand: (_) => false,
      launch: (_) async => true,
    );
    final slow = router.open('slow');
    await router.open('fast');
    await slow;
    expect(log, ['chat 2']);
  });
}

class _Presenter implements LinkPresenter {
  _Presenter(this.log);

  final List<String> log;
  Future<int?> Function(Future<JoinResult> Function() join) answer = (
    _,
  ) async => null;

  @override
  Future<int?> confirmJoin(
    ChatJoinPreview preview,
    Future<JoinResult> Function() join,
  ) {
    log.add('sheet ${preview.title}');
    return answer(join);
  }

  @override
  void showNotice(LinkNotice notice) => log.add('notice ${notice.name}');
}

class _CommandChats implements CommandChats {
  _CommandChats(this.log);

  final List<String> log;
  final groups = <int>{};
  final readOnly = <int>{};
  final bots = <int, String>{};
  var failing = false;

  @override
  bool canSendCommand(int chatId) => !readOnly.contains(chatId);

  @override
  bool isGroup(int chatId) => groups.contains(chatId);

  @override
  Future<String?> botUsername(int userId) async => bots[userId];

  @override
  Future<void> send(int chatId, String text) async {
    if (failing) throw StateError('offline');
    log.add('send $chatId $text');
  }
}
