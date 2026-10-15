import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mollygram/l10n/app_localizations_en.dart';
import 'package:mollygram/l10n/app_localizations_ru.dart';
import 'package:mollygram/src/home/format.dart';
import 'package:mollygram_core/mollygram_core.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  test('labels media and outgoing previews', () {
    final en = AppLocalizationsEn();
    const photo = ChatPreview(
      kind: ChatPreviewKind.photo,
      text: 'Sea\nview',
      date: 0,
      isOutgoing: true,
    );
    expect(formatPreview(en, photo), 'You: Photo, Sea view');

    final ru = AppLocalizationsRu();
    const note = ChatPreview(
      kind: ChatPreviewKind.videoNote,
      text: '',
      date: 0,
      isOutgoing: false,
    );
    expect(formatPreview(ru, note), 'Видеосообщение');
  });

  test('names files and puts a forum sender before the message', () {
    final en = AppLocalizationsEn();
    const file = ChatPreview(
      kind: ChatPreviewKind.document,
      text: '',
      date: 0,
      isOutgoing: true,
      fileName: 'artifacts(4).zip',
    );
    expect(formatPreview(en, file), 'You: artifacts(4).zip');

    const reply = ChatPreview(
      kind: ChatPreviewKind.text,
      text: 'on it',
      date: 0,
      isOutgoing: false,
      topicId: 7,
    );
    expect(formatPreview(en, reply, sender: 'Mark'), 'Mark: on it');
  });

  test('shows the hour today and the date in earlier years', () {
    final now = DateTime(2026, 10, 13, 18);
    int unix(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

    expect(
      formatChatTime(unix(DateTime(2026, 10, 13, 9, 5)), 'en', now: now),
      '09:05',
    );
    expect(
      formatChatTime(unix(DateTime(2024, 3, 2)), 'en', now: now),
      '3/2/2024',
    );
  });
}
