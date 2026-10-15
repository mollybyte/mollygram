import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'proxy_editor.dart';
import 'proxy_providers.dart';

/// "Proxy" at the bottom of the sign-in screens, for networks where
/// Telegram is blocked: it opens the proxy in use, or the one used last,
/// and connects through it on save; with none saved it adds one.
class SignInProxyButton extends ConsumerWidget {
  const SignInProxyButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final proxies = ref.watch(savedProxiesProvider).value ?? const [];
    final inUse = proxies.where((p) => p.isEnabled).firstOrNull;
    return MgTextButton(
      key: const ValueKey('signInProxy'),
      label: inUse == null
          ? l10n.proxy
          : '${l10n.proxy}: ${inUse.settings.server}',
      onPressed: () {
        final SavedProxy? current = proxies.isEmpty
            ? null
            : inUse ??
                  proxies.reduce(
                    (a, b) => b.lastUsedDate > a.lastUsedDate ? b : a,
                  );
        unawaited(showProxyEditor(context, editing: current, connect: true));
      },
    );
  }
}
