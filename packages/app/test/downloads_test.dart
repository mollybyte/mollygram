import 'dart:collection';
import 'dart:convert';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/chat/save_file.dart';
import 'package:mollygram/src/downloads/downloads_bar.dart';
import 'package:mollygram/src/downloads/downloads_sheet.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/settings/preferences.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

const _tick = Duration(milliseconds: 20);

void main() {
  late _FakeTdJson json;
  late TelegramSession session;

  setUp(() async {
    json = _FakeTdJson();
    session = await TelegramSession.attach(
      td.Td.custom(json, td.InlineTdEventSource(json)),
      parameters: TdlibParameters(
        api: const TelegramApiConfig(
          apiId: 12345,
          apiHash: '0123456789abcdef0123456789abcdef',
        ),
        databaseDirectory: '/tmp/mollygram/database',
        filesDirectory: '/tmp/mollygram/files',
        databaseEncryptionKey: Uint8List.fromList([1, 2, 3]),
        systemLanguageCode: 'en',
        deviceModel: 'Mac',
        applicationVersion: '0.1.0',
      ),
    );
  });

  tearDown(() => session.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telegramSessionProvider.overrideWith((ref) async => session),
          preferencesStorageProvider.overrideWithValue(
            MemoryPreferencesStorage(),
          ),
        ],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(child: GlassScope(blur: false, child: home)),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'lists downloads, pauses one and shows a finished one in Finder',
    (tester) async {
      final revealed = <String>[];
      revealFile = (path) async => revealed.add(path);
      addTearDown(() => revealFile = (_) async {});
      json.found = [_fileDownload(1, name: 'report.pdf', completeDate: 50)];
      await pump(tester, const DownloadsSheet());

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('100 B'), findsOneWidget);

      json.push({
        '@type': 'updateFileAddedToDownloads',
        'file_download': _fileDownload(2, name: 'clip.mp4'),
        'counts': _counts(active: 1, completed: 1),
      });
      json.push({'@type': 'updateFile', 'file': _file(2, downloaded: 40)});
      await settle(tester);
      expect(find.text('clip.mp4'), findsOneWidget);
      expect(find.text('40 B of 100 B'), findsOneWidget);
      // Active first.
      expect(
        tester.getTopLeft(find.text('clip.mp4')).dy,
        lessThan(tester.getTopLeft(find.text('report.pdf')).dy),
      );

      await tester.tap(find.byKey(const ValueKey('download.2.action')));
      await settle(tester);
      final pause = json.sent.lastWhere(
        (r) => r['@type'] == 'toggleDownloadIsPaused',
      );
      expect(pause['file_id'], 2);
      expect(pause['is_paused'], isTrue);

      await tester.tap(find.byKey(const ValueKey('downloads.pauseAll')));
      await settle(tester);
      expect(
        json.sent.last,
        containsPair('@type', 'toggleAllDownloadsArePaused'),
      );

      // Hovering a finished row shows its Finder button.
      final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await hover.addPointer();
      await hover.moveTo(tester.getCenter(find.text('report.pdf')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('download.1.reveal')));
      await settle(tester);
      expect(revealed, ['/files/1']);

      await tester.tap(find.byKey(const ValueKey('downloads.clear')));
      await settle(tester);
      expect(
        json.sent.last,
        containsPair('@type', 'removeAllFilesFromDownloads'),
      );
      expect(json.sent.last['only_completed'], isTrue);
      expect(find.text('report.pdf'), findsNothing);
    },
  );

  testWidgets('the bar appears while something downloads and opens the list', (
    tester,
  ) async {
    await pump(
      tester,
      const Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 300, child: DownloadsBar()),
      ),
    );
    expect(find.byKey(const ValueKey('downloadsBar')), findsNothing);

    json.push({
      '@type': 'updateFileAddedToDownloads',
      'file_download': _fileDownload(2, name: 'clip.mp4'),
      'counts': _counts(active: 1),
    });
    json.push({
      '@type': 'updateFileDownloads',
      'total_size': 100,
      'total_count': 1,
      'downloaded_size': 25,
    });
    await settle(tester);
    expect(find.text('1 file downloading'), findsOneWidget);
    expect(find.text('25 B of 100 B'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('downloadsBar')));
    await settle(tester);
    expect(find.byType(DownloadsSheet), findsOneWidget);
    expect(find.text('clip.mp4'), findsOneWidget);

    json.push({
      '@type': 'updateFileRemovedFromDownloads',
      'file_id': 2,
      'counts': _counts(),
    });
    await settle(tester);
    expect(find.byKey(const ValueKey('downloadsBar')), findsNothing);
  });
}

Map<String, Object?> _counts({
  int active = 0,
  int paused = 0,
  int completed = 0,
}) => {
  '@type': 'downloadedFileCounts',
  'active_count': active,
  'paused_count': paused,
  'completed_count': completed,
};

Map<String, Object?> _fileDownload(
  int id, {
  required String name,
  int completeDate = 0,
  bool isPaused = false,
}) => {
  '@type': 'fileDownload',
  'file_id': id,
  'message': {
    '@type': 'message',
    'id': id,
    'chat_id': 7,
    'date': 1000 + id,
    'sender_id': {'@type': 'messageSenderUser', 'user_id': 1},
    'content': {
      '@type': 'messageDocument',
      'document': {
        '@type': 'document',
        'file_name': name,
        'mime_type': 'application/octet-stream',
        'document': _file(id, downloaded: completeDate == 0 ? 0 : 100),
      },
      'caption': {'@type': 'formattedText', 'text': '', 'entities': <Object>[]},
    },
  },
  'add_date': id,
  'complete_date': completeDate,
  'is_paused': isPaused,
};

Map<String, Object?> _file(int id, {required int downloaded}) => {
  '@type': 'file',
  'id': id,
  'size': 100,
  'expected_size': 100,
  'local': {
    '@type': 'localFile',
    'path': downloaded == 100 ? '/files/$id' : '',
    'can_be_downloaded': true,
    'is_downloading_active': downloaded < 100,
    'is_downloading_completed': downloaded == 100,
    'downloaded_size': downloaded,
  },
  'remote': {'@type': 'remoteFile', 'id': 'r', 'unique_id': 'u'},
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var found = <Map<String, Object?>>[];
  var _nextClientId = 0;

  @override
  int createClientId() => ++_nextClientId;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    final extra = decoded.remove('@extra');
    final type = decoded['@type'];
    if (type != 'close') sent.add(decoded);
    final response = switch (type) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'getOption' => {'@type': 'optionValueEmpty'},
      'getChats' => {
        '@type': 'chats',
        'total_count': 0,
        'chat_ids': <Object>[],
      },
      'getChat' => {
        '@type': 'chat',
        'id': 7,
        'title': 'Anna',
        'type': {'@type': 'chatTypePrivate', 'user_id': 1},
        'permissions': {'@type': 'chatPermissions'},
        'positions': <Object>[],
        'chat_lists': <Object>[],
        'available_reactions': {'@type': 'chatAvailableReactionsAll'},
        'notification_settings': {'@type': 'chatNotificationSettings'},
        'video_chat': {'@type': 'videoChat'},
      },
      'searchFileDownloads' => {
        '@type': 'foundFileDownloads',
        'total_counts': _counts(
          active: found
              .where((f) => f['complete_date'] == 0 && f['is_paused'] == false)
              .length,
          paused: found.where((f) => f['is_paused'] == true).length,
          completed: found.where((f) => f['complete_date'] != 0).length,
        ),
        'files': found,
        'next_offset': '',
      },
      _ => {'@type': 'ok'},
    };
    _queue.add(
      jsonEncode({...response, '@client_id': clientId, '@extra': extra}),
    );
    if (type == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      }, clientId);
    }
  }

  void push(Map<String, Object?> update, [int? clientId]) => _queue.add(
    jsonEncode({...update, '@client_id': clientId ?? _nextClientId}),
  );
}
