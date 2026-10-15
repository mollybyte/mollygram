import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ProxyController proxies;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    proxies = ProxyController(tdlib.createClient());
  });

  tearDown(() => tdlib.close());

  Map<String, Object?> sent(String type) =>
      json.sent.lastWhere((r) => r['@type'] == type);

  const socks = ProxySettings(
    server: ' proxy.example ',
    port: 1080,
    kind: ProxyKind.socks5,
    username: 'anna',
    password: 'secret',
  );
  const mtproto = ProxySettings(
    server: 'mt.example',
    port: 443,
    kind: ProxyKind.mtproto,
    secret: 'ee00',
  );

  test('lists the saved proxies of every kind', () async {
    json.proxies = [
      _added(1, _socks('a.example', 1080), enabled: true, lastUsed: 50),
      _added(2, {
        '@type': 'proxyTypeHttp',
        'username': '',
        'password': '',
        'http_only': false,
      }),
      _added(3, {'@type': 'proxyTypeMtproto', 'secret': 'dd11'}),
    ];
    final list = await proxies.list();
    expect(
      [for (final p in list) p.settings.kind],
      [ProxyKind.socks5, ProxyKind.http, ProxyKind.mtproto],
    );
    expect(list.first.isEnabled, isTrue);
    expect(list.first.lastUsedDate, 50);
    expect(list.first.settings.username, 'anna');
    expect(list.last.settings.secret, 'dd11');
  });

  test('adds a proxy and connects through it', () async {
    final saved = await proxies.add(socks);
    final request = sent('addProxy');
    expect(request['enable'], isTrue);
    final proxy = request['proxy']! as Map<String, Object?>;
    expect(proxy['server'], 'proxy.example');
    expect(proxy['port'], 1080);
    expect((proxy['type']! as Map)['@type'], 'proxyTypeSocks5');
    expect((proxy['type']! as Map)['username'], 'anna');
    expect(saved.id, 7);
  });

  test('edits, switches and removes proxies', () async {
    await proxies.edit(3, mtproto, enable: true);
    expect(sent('editProxy')['proxy_id'], 3);
    expect(sent('editProxy')['enable'], isTrue);
    expect(
      ((sent('editProxy')['proxy']! as Map)['type']! as Map)['secret'],
      'ee00',
    );
    await proxies.enable(3);
    expect(sent('enableProxy')['proxy_id'], 3);
    await proxies.disable();
    expect(sent('disableProxy'), isNotNull);
    await proxies.remove(3);
    expect(sent('removeProxy')['proxy_id'], 3);
  });

  test('pings a proxy in milliseconds', () async {
    json.pingSeconds = 0.0425;
    final time = await proxies.ping(mtproto);
    expect(time.inMicroseconds, 42500);
    expect(sent('pingProxy')['proxy'], isNotNull);
  });

  test('reports a proxy that cannot be reached', () async {
    json.pingSeconds = null;
    await expectLater(proxies.ping(mtproto), throwsA(isA<td.TdException>()));
  });

  test('knows a complete proxy', () {
    expect(socks.isComplete, isTrue);
    expect(mtproto.isComplete, isTrue);
    expect(
      const ProxySettings(server: '', port: 1, kind: ProxyKind.http).isComplete,
      isFalse,
    );
    expect(
      const ProxySettings(
        server: 'a',
        port: 70000,
        kind: ProxyKind.http,
      ).isComplete,
      isFalse,
    );
    expect(
      const ProxySettings(
        server: 'a',
        port: 443,
        kind: ProxyKind.mtproto,
      ).isComplete,
      isFalse,
    );
  });

  test('reads back what it writes', () {
    for (final proxy in [socks, mtproto]) {
      final back = ProxySettings.fromTd(proxy.toTd());
      expect(back.kind, proxy.kind);
      expect(back.port, proxy.port);
      expect(back.server, proxy.server.trim());
    }
    expect(
      ProxySettings.fromTd(mtproto.toTd()),
      mtproto,
      reason: 'equal settings are equal',
    );
  });
}

Map<String, Object?> _socks(String server, int port) => {
  '@type': 'proxy',
  'server': server,
  'port': port,
  'type': {
    '@type': 'proxyTypeSocks5',
    'username': 'anna',
    'password': 'secret',
  },
};

Map<String, Object?> _added(
  int id,
  Object proxyOrType, {
  bool enabled = false,
  int lastUsed = 0,
}) => {
  '@type': 'addedProxy',
  'id': id,
  'last_used_date': lastUsed,
  'is_enabled': enabled,
  'comment': '',
  'proxy': (proxyOrType as Map)['@type'] == 'proxy'
      ? proxyOrType
      : {
          '@type': 'proxy',
          'server': 'p$id.example',
          'port': 443,
          'type': proxyOrType,
        },
};

const _error = {'@type': 'error', 'code': 400, 'message': 'Bad request'};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  List<Map<String, Object?>> proxies = const [];
  double? pingSeconds = 0.1;
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
    if (decoded['@type'] != 'close') sent.add(decoded);
    final response = switch (decoded['@type']) {
      'getProxies' => {'@type': 'addedProxies', 'proxies': proxies},
      'addProxy' || 'editProxy' => {
        '@type': 'addedProxy',
        'id': decoded['proxy_id'] ?? 7,
        'last_used_date': 0,
        'is_enabled': decoded['enable'],
        'comment': '',
        'proxy': decoded['proxy'],
      },
      'pingProxy' when pingSeconds == null => _error,
      'pingProxy' => {'@type': 'seconds', 'seconds': pingSeconds},
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
      _queue.add(
        jsonEncode({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosed'},
          '@client_id': 1,
        }),
      );
    }
  }
}
