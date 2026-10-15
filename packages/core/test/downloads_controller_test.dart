import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

import 'support/messages.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late FileController files;
  late DownloadsController downloads;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    final client = tdlib.createClient();
    files = FileController(client);
    downloads = DownloadsController(client, files);
    await files.start();
    await downloads.start();
  });

  tearDown(() async {
    await downloads.dispose();
    await files.dispose();
    await tdlib.close();
  });

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 5));

  test('loads the list and orders active downloads first', () async {
    json.found = [
      _fileDownload(1, completeDate: 50),
      _fileDownload(2, isPaused: true),
      _fileDownload(3),
    ];
    await downloads.load();

    expect(json.sent.single['@type'], 'searchFileDownloads');
    expect(downloads.entries.map((e) => e.fileId), [3, 2, 1]);
    expect(
      downloads.counts,
      const DownloadCounts(active: 1, paused: 1, completed: 1),
    );
    expect(downloads.entries.last.isCompleted, isTrue);
  });

  test('adds a file to the list and follows its progress', () async {
    final lists = <List<int>>[];
    downloads.changes.listen((l) => lists.add([for (final e in l) e.fileId]));

    await downloads.add(5, chatId: 7, messageId: 9);
    expect(json.sent.single['@type'], 'addFileToDownloads');
    expect(json.sent.single['chat_id'], 7);

    json.push({
      '@type': 'updateFileAddedToDownloads',
      'file_download': _fileDownload(5),
      'counts': _counts(active: 1),
    });
    json.push({'@type': 'updateFile', 'file': _file(5, downloaded: 40)});
    await tick();

    expect(lists.last, [5]);
    expect(downloads.entries.single.progress, closeTo(0.4, 0.001));
    expect(downloads.counts.active, 1);

    json.push({
      '@type': 'updateFileDownload',
      'file_id': 5,
      'complete_date': 99,
      'is_paused': false,
      'counts': _counts(completed: 1),
    });
    await tick();
    expect(downloads.entries.single.isCompleted, isTrue);
    expect(downloads.counts.completed, 1);
  });

  test('pauses, resumes, removes and clears', () async {
    json.push({
      '@type': 'updateFileAddedToDownloads',
      'file_download': _fileDownload(5),
      'counts': _counts(active: 1),
    });
    await tick();

    await downloads.pause(5);
    await downloads.resume(5);
    await downloads.pauseAll();
    await downloads.remove(5);
    await downloads.clear();

    expect(json.sent.map((r) => r['@type']), [
      'toggleDownloadIsPaused',
      'toggleDownloadIsPaused',
      'toggleAllDownloadsArePaused',
      'removeFileFromDownloads',
      'removeAllFilesFromDownloads',
    ]);
    expect(json.sent[0]['is_paused'], isTrue);
    expect(json.sent[1]['is_paused'], isFalse);
    expect(json.sent[4]['only_completed'], isTrue);
    expect(downloads.entries, isEmpty);
  });

  test('keeps the overall totals', () async {
    json.push({
      '@type': 'updateFileDownloads',
      'total_size': 200,
      'total_count': 2,
      'downloaded_size': 50,
    });
    await tick();
    expect(downloads.totals.progress, 0.25);
    expect(downloads.totals.totalCount, 2);
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
  int completeDate = 0,
  bool isPaused = false,
}) => {
  '@type': 'fileDownload',
  'file_id': id,
  'message': tdMessage(
    id: id,
    chatId: 7,
    content: td.MessageDocument(
      document: td.Document(
        fileName: 'file$id.pdf',
        mimeType: 'application/pdf',
        minithumbnail: null,
        thumbnail: null,
        document: td.File.fromJson(_file(id, downloaded: 0)),
      ),
      caption: const td.FormattedText(text: '', entities: []),
    ),
  ).toJson(),
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

  /// What searchFileDownloads answers with.
  var found = <Map<String, Object?>>[];

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
    final response = switch (decoded['@type']) {
      'addFileToDownloads' => _file(5, downloaded: 0),
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
