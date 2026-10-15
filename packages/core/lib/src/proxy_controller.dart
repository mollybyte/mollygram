import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// The kinds of proxy TDLib can connect through.
enum ProxyKind { socks5, http, mtproto }

/// Where a proxy is and how to sign in to it.
final class ProxySettings {
  const ProxySettings({
    required this.server,
    required this.port,
    required this.kind,
    this.username = '',
    this.password = '',
    this.secret = '',
  });

  factory ProxySettings.fromTd(td.Proxy proxy) => switch (proxy.type) {
    td.ProxyTypeSocks5(:final username, :final password) => ProxySettings(
      server: proxy.server,
      port: proxy.port,
      kind: ProxyKind.socks5,
      username: username,
      password: password,
    ),
    td.ProxyTypeHttp(:final username, :final password) => ProxySettings(
      server: proxy.server,
      port: proxy.port,
      kind: ProxyKind.http,
      username: username,
      password: password,
    ),
    td.ProxyTypeMtproto(:final secret) => ProxySettings(
      server: proxy.server,
      port: proxy.port,
      kind: ProxyKind.mtproto,
      secret: secret,
    ),
  };

  final String server;
  final int port;
  final ProxyKind kind;

  /// For SOCKS5 and HTTP; empty when the proxy needs no sign-in.
  final String username;
  final String password;

  /// For MTProto.
  final String secret;

  /// Whether TDLib would take it: a server, a port in range and, for
  /// MTProto, a secret.
  bool get isComplete =>
      server.trim().isNotEmpty &&
      port > 0 &&
      port < 65536 &&
      (kind != ProxyKind.mtproto || secret.trim().isNotEmpty);

  td.Proxy toTd() => td.Proxy(
    server: server.trim(),
    port: port,
    type: switch (kind) {
      ProxyKind.socks5 => td.ProxyTypeSocks5(
        username: username,
        password: password,
      ),
      ProxyKind.http => td.ProxyTypeHttp(
        username: username,
        password: password,
        httpOnly: false,
      ),
      ProxyKind.mtproto => td.ProxyTypeMtproto(secret: secret.trim()),
    },
  );

  @override
  bool operator ==(Object other) =>
      other is ProxySettings &&
      other.server == server &&
      other.port == port &&
      other.kind == kind &&
      other.username == username &&
      other.password == password &&
      other.secret == secret;

  @override
  int get hashCode =>
      Object.hash(server, port, kind, username, password, secret);
}

/// A proxy saved in TDLib.
final class SavedProxy {
  const SavedProxy({
    required this.id,
    required this.settings,
    this.isEnabled = false,
    this.lastUsedDate = 0,
  });

  factory SavedProxy.fromTd(td.AddedProxy proxy) => SavedProxy(
    id: proxy.id,
    settings: ProxySettings.fromTd(proxy.proxy),
    isEnabled: proxy.isEnabled,
    lastUsedDate: proxy.lastUsedDate,
  );

  final int id;
  final ProxySettings settings;

  /// The one TDLib connects through; at most one is.
  final bool isEnabled;

  /// Unix time it was last used; 0 for never.
  final int lastUsedDate;
}

/// The proxies TDLib knows: adding, editing, switching and pinging them.
final class ProxyController {
  ProxyController(this._client);

  final td.TdClient _client;

  /// Every saved proxy, in TDLib's order.
  Future<List<SavedProxy>> list() async {
    final proxies = await _client.send(const td.GetProxies());
    return [for (final p in proxies.proxies) SavedProxy.fromTd(p)];
  }

  /// Saves [proxy]; with [enable], connects through it.
  Future<SavedProxy> add(ProxySettings proxy, {bool enable = true}) async =>
      SavedProxy.fromTd(
        await _client.send(
          td.AddProxy(proxy: proxy.toTd(), enable: enable, comment: ''),
        ),
      );

  Future<SavedProxy> edit(
    int id,
    ProxySettings proxy, {
    bool enable = false,
  }) async => SavedProxy.fromTd(
    await _client.send(
      td.EditProxy(
        proxyId: id,
        proxy: proxy.toTd(),
        enable: enable,
        comment: '',
      ),
    ),
  );

  /// Connects through proxy [id] from now on.
  Future<void> enable(int id) => _client.send(td.EnableProxy(proxyId: id));

  /// Connects directly again; the proxies stay saved.
  Future<void> disable() => _client.send(const td.DisableProxy());

  Future<void> remove(int id) => _client.send(td.RemoveProxy(proxyId: id));

  /// How long a round trip to Telegram through [proxy] takes.
  Future<Duration> ping(ProxySettings proxy) async {
    final seconds = await _client.send(td.PingProxy(proxy: proxy.toTd()));
    return Duration(microseconds: (seconds.seconds * 1000000).round());
  }
}
