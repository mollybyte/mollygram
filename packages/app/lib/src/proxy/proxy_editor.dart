import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import 'proxy_providers.dart';

/// Opens the proxy sheet: [editing] a saved proxy, or adding one that
/// starts from [initial]. From a proxy link ([fromLink]) the sheet asks
/// whether to add the proxy and connect through it.
Future<void> showProxyEditor(
  BuildContext context, {
  SavedProxy? editing,
  ProxySettings? initial,
  bool fromLink = false,
  bool connect = false,
}) => showMgSheet<void>(
  context,
  ProxyEditor(
    editing: editing,
    initial: initial ?? editing?.settings,
    fromLink: fromLink,
    connect: connect,
  ),
);

/// The proxy's type, server, port and sign-in, with a check that pings
/// it before it is saved.
class ProxyEditor extends ConsumerStatefulWidget {
  const ProxyEditor({
    super.key,
    this.editing,
    this.initial,
    this.fromLink = false,
    this.connect = false,
  });

  final SavedProxy? editing;
  final ProxySettings? initial;
  final bool fromLink;

  /// Saving [editing] also connects through it, as on the sign-in screen.
  final bool connect;

  @override
  ConsumerState<ProxyEditor> createState() => _ProxyEditorState();
}

enum _Check { idle, checking, done }

class _ProxyEditorState extends ConsumerState<ProxyEditor> {
  late var _kind = widget.initial?.kind ?? ProxyKind.socks5;
  late final _server = TextEditingController(text: widget.initial?.server);
  late final _port = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial!.port}',
  );
  late final _username = TextEditingController(text: widget.initial?.username);
  late final _password = TextEditingController(text: widget.initial?.password);
  late final _secret = TextEditingController(text: widget.initial?.secret);
  var _check = _Check.idle;
  Duration? _ping;
  var _saving = false;
  var _showSecret = false;
  String? _error;

  ProxyController get _proxies =>
      ref.read(telegramSessionProvider).requireValue.proxies;

  @override
  void initState() {
    super.initState();
    for (final field in [_server, _port, _username, _password, _secret]) {
      field.addListener(_changed);
    }
    // A proxy from a link is checked right away, to decide on.
    if (widget.fromLink && _settings.isComplete) unawaited(_runCheck());
  }

  @override
  void dispose() {
    for (final field in [_server, _port, _username, _password, _secret]) {
      field.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {
    _check = _Check.idle;
    _error = null;
  });

  ProxySettings get _settings => ProxySettings(
    server: _server.text.trim(),
    port: int.tryParse(_port.text.trim()) ?? 0,
    kind: _kind,
    username: _kind == ProxyKind.mtproto ? '' : _username.text,
    password: _kind == ProxyKind.mtproto ? '' : _password.text,
    secret: _kind == ProxyKind.mtproto ? _secret.text.trim() : '',
  );

  Future<void> _runCheck() async {
    final settings = _settings;
    setState(() => _check = _Check.checking);
    Duration? ping;
    try {
      ping = await _proxies.ping(settings);
    } on Object {
      ping = null;
    }
    if (!mounted || settings != _settings) return;
    setState(() {
      _check = _Check.done;
      _ping = ping;
    });
  }

  Future<void> _save() async {
    final settings = _settings;
    if (!settings.isComplete || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final editing = widget.editing;
      if (editing == null) {
        await _proxies.add(settings, enable: true);
      } else {
        await _proxies.edit(
          editing.id,
          settings,
          enable: editing.isEnabled || widget.connect,
        );
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppLocalizations.of(context).saveFailed;
      });
      return;
    }
    ref
      ..invalidate(savedProxiesProvider)
      ..invalidate(proxyPingProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final editing = widget.editing!;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.proxyRemoveTitle(
        '${editing.settings.server}:${editing.settings.port}',
      ),
      confirmLabel: l10n.proxyRemoveAction,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _proxies.remove(editing.id);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.saveFailed;
      });
      return;
    }
    ref
      ..invalidate(savedProxiesProvider)
      ..invalidate(proxyPingProvider);
    if (mounted) Navigator.of(context).pop();
  }

  void _close() {
    if (!_saving) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = _settings;
    final title = widget.fromLink
        ? l10n.proxyFromLink
        : widget.editing == null
        ? l10n.addProxy
        : l10n.editProxy;
    final badSecret =
        _kind == ProxyKind.mtproto &&
        _secret.text.trim().isNotEmpty &&
        !ProxySettings.isValidSecret(_secret.text);
    return PopScope(
      canPop: !_saving,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _close,
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              unawaited(_save()),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
              unawaited(_save()),
        },
        // From a link no field takes focus, so the sheet itself does and
        // Enter and Esc still work.
        child: Focus(
          autofocus: widget.fromLink,
          child: SizedBox(
            width: 360,
            child: Glass(
              radius: MgRadius.popover,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: mgTextStyle(c, weight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _KindPicker(
                    value: _kind,
                    enabled: !_saving,
                    onChanged: (kind) => setState(() {
                      _kind = kind;
                      _check = _Check.idle;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          key: const ValueKey('server'),
                          controller: _server,
                          hint: l10n.proxyServer,
                          autofocus: !widget.fromLink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 84,
                        child: _Field(
                          key: const ValueKey('port'),
                          controller: _port,
                          hint: l10n.proxyPort,
                          digits: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedSize(
                    duration: MgMotion.standard,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _kind == ProxyKind.mtproto
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Field(
                                key: const ValueKey('secret'),
                                controller: _secret,
                                hint: l10n.proxySecret,
                                obscure: !_showSecret,
                                trailing: MgIconButton(
                                  key: const ValueKey('revealSecret'),
                                  icon: _showSecret ? _eyeClosed : _eye,
                                  tooltip: _showSecret
                                      ? l10n.proxyHideSecret
                                      : l10n.proxyShowSecret,
                                  iconSize: 15,
                                  onPressed: () => setState(
                                    () => _showSecret = !_showSecret,
                                  ),
                                ),
                              ),
                              if (badSecret)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    2,
                                    4,
                                    2,
                                    0,
                                  ),
                                  child: Text(
                                    l10n.proxyInvalidSecret,
                                    style: mgTextStyle(
                                      c,
                                      size: MgType.caption,
                                      color: MgDestructive.color,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            children: [
                              _Field(
                                key: const ValueKey('username'),
                                controller: _username,
                                hint: l10n.proxyUsername,
                              ),
                              const SizedBox(height: 8),
                              _Field(
                                key: const ValueKey('password'),
                                controller: _password,
                                hint: l10n.proxyPassword,
                                obscure: true,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      MgTextButton(
                        label: l10n.proxyCheck,
                        onPressed:
                            settings.isComplete && _check != _Check.checking
                            ? () => unawaited(_runCheck())
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MgMotion.standard,
                          child: Text(
                            switch (_check) {
                              _Check.idle => '',
                              _Check.checking => l10n.proxyChecking,
                              _Check.done => switch (_ping) {
                                final ping? => l10n.proxyPing(
                                  ping.inMilliseconds,
                                ),
                                null => l10n.proxyUnavailable,
                              },
                            },
                            key: ValueKey((_check, _ping)),
                            style: mgTextStyle(
                              c,
                              size: MgType.small,
                              color: _check == _Check.done && _ping == null
                                  ? MgDestructive.color
                                  : c.fg2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 6),
                    Text(
                      error,
                      style: mgTextStyle(
                        c,
                        size: MgType.caption,
                        color: MgDestructive.color,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (widget.editing != null)
                        MgTextButton(
                          label: l10n.proxyRemove,
                          onPressed: _saving
                              ? null
                              : () => unawaited(_remove()),
                        ),
                      const Spacer(),
                      MgTextButton(
                        label: l10n.cancel,
                        onPressed: _saving ? null : _close,
                      ),
                      const SizedBox(width: 8),
                      MgPrimaryButton(
                        label: widget.editing == null || widget.connect
                            ? l10n.proxyConnect
                            : l10n.save,
                        height: 28,
                        loading: _saving,
                        onPressed: settings.isComplete && !_saving
                            ? () => unawaited(_save())
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SOCKS5, HTTP and MTProto as a segmented control.
class _KindPicker extends StatelessWidget {
  const _KindPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ProxyKind value;
  final bool enabled;
  final ValueChanged<ProxyKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final kind in ProxyKind.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: kind == value,
                label: proxyKindName(kind),
                excludeSemantics: true,
                child: MouseRegion(
                  cursor: enabled
                      ? SystemMouseCursors.click
                      : MouseCursor.defer,
                  child: GestureDetector(
                    onTap: enabled ? () => onChanged(kind) : null,
                    child: AnimatedContainer(
                      duration: MgMotion.standard,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kind == value
                            ? c.windowBackground
                            : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: kind == value
                            ? const [
                                BoxShadow(
                                  color: Color(0x1F000000),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        proxyKindName(kind),
                        style: mgTextStyle(
                          c,
                          size: MgType.small,
                          weight: kind == value ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.hint,
    this.digits = false,
    this.obscure = false,
    this.autofocus = false,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final bool digits;
  final bool obscure;
  final bool autofocus;

  /// A button at the end of the field.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = mgTextStyle(c, height: 1.3);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              obscureText: obscure,
              keyboardType: digits ? TextInputType.number : null,
              inputFormatters: digits
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ]
                  : null,
              style: style,
              cursorHeight: 15,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: style.copyWith(color: c.fg2),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

const _eye = MgIconData(
  'eye',
  '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/>'
      '<circle cx="12" cy="12" r="3"/>',
);
const _eyeClosed = MgIconData(
  'eyeClosed',
  '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/>'
      '<circle cx="12" cy="12" r="3"/><path d="M4 4l16 16"/>',
);
