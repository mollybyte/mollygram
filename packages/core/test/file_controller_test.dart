import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late FileController files;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    files = FileController(tdlib.createClient());
    await files.start();
  });

  tearDown(() async {
    await files.dispose();
    await tdlib.close();
  });

  test('follows a download through updateFile', () async {
    final initial = td.File.fromJson(_file(5, downloaded: 0));
    final states = <int>[];
    files.changesOf(5).listen((f) => states.add(f.local.downloadedSize));

    await files.download(5);
    json.push({'@type': 'updateFile', 'file': _file(5, downloaded: 100)});
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(json.sent.single['@type'], 'downloadFile');
    expect(json.sent.single['synchronous'], isFalse);
    expect(states, [0, 100]);
    expect(downloadedPath(files.latest(initial)), '/files/5');
  });
}

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
    if (decoded['@type'] != 'close') sent.add(decoded);
    final response = decoded['@type'] == 'downloadFile'
        ? _file(5, downloaded: 0)
        : {'@type': 'ok'};
    _queue.add(
      jsonEncode({
        ...response,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
