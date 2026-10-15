import 'package:mollygram_core/mollygram_core.dart';
import 'package:test/test.dart';

void main() {
  group('normalize', () {
    String? n(String raw) => TelegramLinks.normalize(raw)?.toString();

    test('turns a mention into a t.me link', () {
      expect(n('@durov'), 'https://t.me/durov');
      expect(n(' @tdlib_bot '), 'https://t.me/tdlib_bot');
    });

    test('rejects mentions that are not usernames', () {
      expect(n('@'), isNull);
      expect(n('@no-dash'), isNull);
    });

    test('adds https to links without a scheme', () {
      expect(n('t.me/durov'), 'https://t.me/durov');
      expect(n('example.com/a?b=1'), 'https://example.com/a?b=1');
      expect(n('t.me/+AbCdEf'), 'https://t.me/+AbCdEf');
    });

    test('keeps a host with a port as a host', () {
      expect(n('example.com:8080/x'), 'https://example.com:8080/x');
    });

    test('keeps links with a scheme', () {
      expect(n('tg://resolve?domain=durov'), 'tg://resolve?domain=durov');
      expect(n('mailto:a@b.co'), 'mailto:a@b.co');
      expect(n('tel:+1 555 0100'), 'tel:+1%20555%200100');
      expect(n('HTTPS://T.ME/durov'), 'https://t.me/durov');
    });

    test('rejects blank text and text with spaces', () {
      expect(n(''), isNull);
      expect(n('   '), isNull);
      expect(n('two words'), isNull);
    });
  });

  group('isTelegram', () {
    bool t(String url) => TelegramLinks.isTelegram(Uri.parse(url));

    test('accepts tg links and Telegram hosts', () {
      expect(t('tg://join?invite=abc'), isTrue);
      expect(t('https://t.me/durov/12'), isTrue);
      expect(t('http://telegram.me/durov'), isTrue);
      expect(t('https://telegram.dog/durov'), isTrue);
      expect(t('https://www.t.me/durov'), isTrue);
      expect(t('https://durov.t.me'), isTrue);
      expect(t('https://T.ME/c/123/45'), isTrue);
    });

    test('leaves other sites alone', () {
      expect(t('https://telegram.org/blog'), isFalse);
      expect(t('https://nott.me/x'), isFalse);
      expect(t('https://t.me.evil.com/x'), isFalse);
      expect(t('ftp://t.me/x'), isFalse);
      expect(t('mailto:a@t.me'), isFalse);
    });
  });

  test('isExternal allows web, mail and phone only', () {
    bool e(String url) => TelegramLinks.isExternal(Uri.parse(url));
    expect(e('https://example.com'), isTrue);
    expect(e('http://example.com'), isTrue);
    expect(e('mailto:a@b.co'), isTrue);
    expect(e('tel:+123'), isTrue);
    expect(e('file:///etc/passwd'), isFalse);
    expect(e('javascript:alert(1)'), isFalse);
  });

  test('recognizes hashtags, cashtags and bot commands', () {
    expect(TelegramLinks.hashtag(' #news '), '#news');
    expect(TelegramLinks.hashtag(r'$TON'), r'$TON');
    expect(TelegramLinks.hashtag('#'), isNull);
    expect(TelegramLinks.hashtag('#two words'), isNull);
    expect(TelegramLinks.botCommand('/start'), '/start');
    expect(TelegramLinks.botCommand('/help@some_bot'), '/help@some_bot');
    expect(TelegramLinks.botCommand('/a/b'), isNull);
    expect(TelegramLinks.botCommand('start'), isNull);
  });

  test('makes and reads tg://user links', () {
    final link = TelegramLinks.userLink(55);
    expect(link.toString(), 'tg://user?id=55');
    expect(TelegramLinks.userIdOf(link), 55);
    expect(TelegramLinks.userIdOf(Uri.parse('tg://user?id=x')), isNull);
    expect(TelegramLinks.userIdOf(Uri.parse('tg://resolve?domain=a')), isNull);
  });

  test('turns t.me/s/ previews into channel links', () {
    Uri unwrap(String s) => TelegramLinks.withoutWebPreview(Uri.parse(s));
    expect(unwrap('https://t.me/s/news').toString(), 'https://t.me/news');
    expect(unwrap('https://t.me/s/news/42').toString(), 'https://t.me/news/42');
    expect(unwrap('https://t.me/s').toString(), 'https://t.me/s');
    expect(
      unwrap('https://example.com/s/news').toString(),
      'https://example.com/s/news',
    );
  });
}
