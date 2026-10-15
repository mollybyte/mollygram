import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../proxy/proxy_editor.dart';
import '../proxy/proxy_providers.dart';
import '../session/providers.dart';
import 'settings_style.dart';
import 'settings_window.dart';

/// The "Proxy" entry of the settings source list.
final proxySection = SettingsSection(
  id: 'proxy',
  icon: _shield,
  tint: const Color(0xFF30B0C7),
  title: (l10n) => l10n.proxy,
  keywords: (l10n) => [
    l10n.useProxy,
    l10n.addProxy,
    'SOCKS5',
    'MTProto',
    'HTTP',
  ],
  builder: (context) => const ProxyPage(),
);

/// Proxies, after Telegram Desktop's: "Use proxy" switches between the
/// selected one and a direct connection, each saved proxy shows its
/// ping, a click connects through it, and Edit opens its sheet.
class ProxyPage extends ConsumerStatefulWidget {
  const ProxyPage({super.key});

  @override
  ConsumerState<ProxyPage> createState() => _ProxyPageState();
}

class _ProxyPageState extends ConsumerState<ProxyPage> {
  String? _error;

  ProxyController get _proxies =>
      ref.read(telegramSessionProvider).requireValue.proxies;

  /// Runs [change], then reads the list again; a failure shows under it.
  Future<void> _apply(Future<void> Function() change) async {
    setState(() => _error = null);
    try {
      await change();
    } on Object {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).saveFailed);
      }
    }
    ref.invalidate(savedProxiesProvider);
  }

  /// Turning the switch on connects through the proxy used last.
  Future<void> _setUse(List<SavedProxy> proxies, bool use) => _apply(() {
    if (!use) return _proxies.disable();
    final last = proxies.reduce(
      (a, b) => b.lastUsedDate > a.lastUsedDate ? b : a,
    );
    return _proxies.enable(last.id);
  });

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final proxies = ref.watch(savedProxiesProvider).value ?? const [];
    final inUse = proxies.any((p) => p.isEnabled);
    return SettingsPage(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
          child: Text(
            l10n.proxyHint,
            style: mgTextStyle(c, color: c.fg2, height: 1.35),
          ),
        ),
        SettingsGroup(
          children: [
            SettingsSwitchRow(
              key: const ValueKey('useProxy'),
              title: l10n.useProxy,
              value: inUse,
              onChanged: proxies.isEmpty
                  ? null
                  : (use) => unawaited(_setUse(proxies, use)),
            ),
          ],
        ),
        SettingsGroup(
          title: l10n.savedProxies,
          footer: _error != null
              ? SettingsFooter(_error!, error: true)
              : proxies.isEmpty
              ? SettingsFooter(l10n.proxyNone)
              : null,
          children: [
            SettingsRow(
              key: const ValueKey('addProxy'),
              leading: SettingsSymbol(icon: _plus, tint: c.accent),
              title: l10n.addProxy,
              onTap: () => unawaited(showProxyEditor(context)),
            ),
            for (final proxy in proxies)
              _ProxyRow(
                key: ValueKey(('proxy', proxy.id)),
                proxy: proxy,
                onSelect: proxy.isEnabled
                    ? null
                    : () => unawaited(_apply(() => _proxies.enable(proxy.id))),
                onEdit: () =>
                    unawaited(showProxyEditor(context, editing: proxy)),
              ),
          ],
        ),
      ],
    );
  }
}

/// A saved proxy: a check mark on the one in use, its address, its type
/// and ping.
class _ProxyRow extends ConsumerWidget {
  const _ProxyRow({
    super.key,
    required this.proxy,
    required this.onSelect,
    required this.onEdit,
  });

  final SavedProxy proxy;
  final VoidCallback? onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = proxy.settings;
    final ping = switch (ref.watch(proxyPingProvider(settings))) {
      AsyncData(value: final Duration time) => l10n.proxyPing(
        time.inMilliseconds,
      ),
      AsyncData() || AsyncError() => l10n.proxyUnavailable,
      _ => l10n.proxyChecking,
    };
    return Semantics(
      selected: proxy.isEnabled,
      child: SettingsRow(
        leading: SizedBox.square(
          dimension: 22,
          child: proxy.isEnabled
              ? MgIcon(_check, size: 16, stroke: 2.4, color: c.accent)
              : null,
        ),
        title: '${settings.server}:${settings.port}',
        subtitle: '${proxyKindName(settings.kind)} · $ping',
        onTap: onSelect,
        trailing: SettingsButton(
          key: ValueKey(('editProxy', proxy.id)),
          label: l10n.proxyEditButton,
          onPressed: onEdit,
        ),
      ),
    );
  }
}

const _plus = MgIconData('plus', '<path d="M12 5v14M5 12h14"/>');
const _check = MgIconData('check', '<path d="M5 12.5l4.5 4.5L19 7"/>');
const _shield = MgIconData(
  'shield',
  '<path d="M12 3l7 3v5.5c0 4.4-3 8.2-7 9.5-4-1.3-7-5.1-7-9.5V6z"/>',
);
