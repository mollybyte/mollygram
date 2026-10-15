import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../session/providers.dart';

/// The proxies saved in TDLib; invalidated after each change.
final savedProxiesProvider = FutureProvider.autoDispose<List<SavedProxy>>(
  (ref) => ref.watch(telegramSessionProvider).requireValue.proxies.list(),
);

/// The round trip through a proxy; null when it can't be reached.
final proxyPingProvider = FutureProvider.autoDispose
    .family<Duration?, ProxySettings>((ref, proxy) async {
      final proxies = ref.watch(telegramSessionProvider).requireValue.proxies;
      try {
        return await proxies.ping(proxy);
      } on Object {
        return null;
      }
    });

/// How a proxy's type reads: its protocol's own name in every language.
String proxyKindName(ProxyKind kind) => switch (kind) {
  ProxyKind.socks5 => 'SOCKS5',
  ProxyKind.http => 'HTTP',
  ProxyKind.mtproto => 'MTProto',
};
