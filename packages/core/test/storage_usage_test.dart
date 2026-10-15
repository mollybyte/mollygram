import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late td.Td tdlib;
  tearDown(() => tdlib.close());

  (StorageManager, _FakeTdJson) storage(
    Map<String, Map<String, Object?>> responses,
  ) {
    final json = _FakeTdJson(responses);
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    return (StorageManager(tdlib.createClient()), json);
  }

  Map<String, Object?> byType(String type, int size) => {
    '@type': 'storageStatisticsByFileType',
    'file_type': {'@type': type},
    'size': size,
    'count': 1,
  };

  test('sums the per-chat statistics into categories', () async {
    final (manager, _) = storage({
      'getStorageStatistics': {
        '@type': 'storageStatistics',
        'size': 0,
        'count': 0,
        'by_chat': [
          {
            '@type': 'storageStatisticsByChat',
            'chat_id': 1,
            'by_file_type': [
              byType('fileTypePhoto', 100),
              byType('fileTypeVideoNote', 30),
              byType('fileTypeSecure', 999),
            ],
          },
          {
            '@type': 'storageStatisticsByChat',
            'chat_id': 0,
            'by_file_type': [
              byType('fileTypePhoto', 50),
              byType('fileTypeAnimation', 20),
              byType('fileTypeThumbnail', 5),
              byType('fileTypeDocument', 0),
            ],
          },
        ],
      },
      'getStorageStatisticsFast': {
        '@type': 'storageStatisticsFast',
        'database_size': 4000,
      },
    });
    final usage = await manager.usage();

    expect(usage.sizes, {
      StorageCategory.photos: 150,
      StorageCategory.videos: 50,
      StorageCategory.other: 5,
    });
    expect(usage.filesSize, 205);
    expect(usage.sizeOf(StorageCategory.files), 0);
    expect(usage.databaseSize, 4000);
  });

  test('clears every file type of the chosen categories', () async {
    final (manager, client) = storage({
      'optimizeStorage': {'@type': 'storageStatistics', 'by_chat': <Object>[]},
    });
    await manager.clear({});
    expect(client.sent, isEmpty);

    await manager.clear({StorageCategory.files, StorageCategory.stickers});
    final request = client.sent.single;
    expect(request['size'], 0);
    expect(request['ttl'], 0);
    expect(request['immunity_delay'], 0);
    expect(request['file_types'], [
      {'@type': 'fileTypeDocument'},
      {'@type': 'fileTypeSticker'},
    ]);
  });

  test('every category clears the types it counts', () {
    for (final category in StorageCategory.values) {
      for (final type in fileTypesOf(category)) {
        expect(storageCategoryOf(type), category, reason: '$type');
      }
    }
  });
}

final class _FakeTdJson implements td.TdJson {
  _FakeTdJson(this.responses);

  final Map<String, Map<String, Object?>> responses;
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  @override
  int createClientId() => 1;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    final extra = decoded.remove('@extra');
    if (responses.containsKey(decoded['@type'])) sent.add(decoded);
    _queue.add(
      jsonEncode({
        ...responses[decoded['@type']] ?? {'@type': 'ok'},
        '@client_id': clientId,
        '@extra': extra,
      }),
    );
    if (decoded['@type'] == 'close') {
      _queue.add(
        jsonEncode({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosed'},
          '@client_id': clientId,
        }),
      );
    }
  }
}
