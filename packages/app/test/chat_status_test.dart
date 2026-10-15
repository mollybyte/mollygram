import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mollygram/l10n/app_localizations_en.dart';
import 'package:mollygram/l10n/app_localizations_ru.dart';
import 'package:mollygram/src/home/chat_status.dart';
import 'package:mollygram_core/mollygram_core.dart';

void main() {
  final en = AppLocalizationsEn();
  final ru = AppLocalizationsRu();
  final now = DateTime(2026, 10, 15, 12);

  setUpAll(initializeDateFormatting);

  String status(ChatStatus s, {AppLocalizationsEn? l10n}) =>
      formatChatStatus(l10n ?? en, s, 'en', now: now).$1;

  test('says when a user was last seen, like the official client', () {
    ChatStatus seen(Duration ago) =>
        ChatStatusUser(PresenceOffline(now.subtract(ago)));
    expect(
      formatChatStatus(
        en,
        ChatStatusUser(PresenceOnline(now.add(const Duration(minutes: 1)))),
        'en',
        now: now,
      ),
      ('online', true),
    );
    expect(status(seen(const Duration(seconds: 20))), 'last seen just now');
    expect(status(seen(const Duration(minutes: 5))), 'last seen 5 minutes ago');
    expect(status(seen(const Duration(minutes: 1))), 'last seen 1 minute ago');
    expect(status(seen(const Duration(hours: 3))), 'last seen today at 09:00');
    expect(
      status(seen(const Duration(hours: 20))),
      'last seen yesterday at 16:00',
    );
    expect(status(seen(const Duration(days: 9))), 'last seen 10/6/2026');
    expect(
      status(const ChatStatusUser(PresenceRecently())),
      'last seen recently',
    );
    // An online status that ran out is not "online".
    expect(
      status(
        ChatStatusUser(PresenceOnline(now.subtract(const Duration(hours: 1)))),
      ),
      'last seen today at 11:00',
    );
  });

  test('counts members and subscribers in both languages', () {
    expect(
      status(const ChatStatusGroup(members: 1200, online: 0)),
      '1200 members',
    );
    expect(
      status(const ChatStatusGroup(members: 12, online: 3)),
      '12 members, 3 online',
    );
    expect(status(const ChatStatusGroup(members: 0, online: 0)), 'group');
    expect(
      formatChatStatus(
        ru,
        const ChatStatusChannel(subscribers: 22),
        'ru',
        now: now,
      ).$1,
      '22 подписчика',
    );
    expect(
      formatChatStatus(
        ru,
        const ChatStatusGroup(members: 5, online: 2),
        'ru',
        now: now,
      ).$1,
      '5 участников, 2 в сети',
    );
  });

  test('names who is doing what in groups only', () {
    const alina = ChatActor(name: 'Alina', activity: ChatActivity.typing);
    const boris = ChatActor(
      name: 'Boris',
      activity: ChatActivity.recordingVoice,
    );
    const vera = ChatActor(name: 'Vera', activity: ChatActivity.typing);
    expect(
      formatActivity(en, [boris], named: false),
      'recording a voice message',
    );
    expect(
      formatActivity(en, [boris], named: true),
      'Boris is recording a voice message',
    );
    expect(
      formatActivity(en, [alina, boris], named: true),
      'Alina and Boris are typing',
    );
    expect(
      formatActivity(en, [alina, boris, vera], named: true),
      'Alina and 2 others are typing',
    );
    expect(formatActivity(ru, [alina], named: true), 'Alina печатает');
  });
}
