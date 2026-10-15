import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/links/link_router.dart';
import 'package:mollygram_core/mollygram_core.dart';

void main() {
  late Map<String, LinkTarget?> targets;
  late List<String> log;
  late _Presenter presenter;
  late LinkRouter router;
  late Set<String> commands;
  Object? resolveError;

  setUp(() {
    targets = {};
    log = [];
    commands = {'app.settings'};
    resolveError = null;
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
      search: (hashtag) => log.add('search $hashtag'),
      sendCommand: (command) async {
        log.add('send $command');
        return true;
      },
    )..presenter = presenter;
  });

  test('searches hashtags and sends bot commands', () async {
    targets['#news'] = const HashtagLinkTarget('#news');
    targets['/start'] = const BotCommandLinkTarget('/start');
    await router.open('#news');
    await router.open('/start');
    expect(log, ['search #news', 'send /start']);
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
