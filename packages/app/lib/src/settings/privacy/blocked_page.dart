import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../../chat/message_tile.dart' show SenderAvatar;
import '../settings_style.dart';
import 'privacy_page.dart';
import 'privacy_providers.dart';
import 'user_picker.dart';

/// The people and chats the user blocked, after TelegramSwift's
/// BlockedPeersViewController: "Block someone" on top, then the list with
/// Unblock on each, a page at a time.
class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  List<PrivacyPeer>? _peers;
  var _hasMore = false;
  var _loading = false;
  String? _error;

  /// Unblocked here, hidden at once.
  final _unblocked = <(bool, int)>{};
  StreamSubscription<void>? _changes;

  PrivacySettingsController get _privacy => ref.read(privacyControllerProvider);

  @override
  void initState() {
    super.initState();
    _changes = _privacy.blockedChanges.listen((_) => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  /// The first page, or the next one with [more]. A reload asks for as
  /// many as are shown, so the list doesn't fold back to one page.
  Future<void> _load({bool more = false}) async {
    if (_loading && more) return;
    final shown = _peers?.length ?? 0;
    setState(() => _loading = true);
    try {
      final page = await _privacy.blocked(
        offset: more ? shown : 0,
        limit: more
            ? PrivacySettingsController.pageSize
            : shown.clamp(PrivacySettingsController.pageSize, 500),
      );
      if (!mounted) return;
      setState(() {
        _peers = [if (more) ...?_peers, ...page.peers];
        _hasMore = page.hasMore && page.peers.isNotEmpty;
        _unblocked.clear();
        _loading = false;
        _error = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).privacyLoadFailed;
      });
    }
  }

  Future<void> _unblock(PrivacyPeer peer) async {
    final key = (peer.isChat, peer.id);
    setState(() {
      _unblocked.add(key);
      _error = null;
    });
    try {
      await _privacy.unblock(peer);
    } on Object {
      if (!mounted) return;
      setState(() {
        _unblocked.remove(key);
        _error = AppLocalizations.of(context).saveFailed;
      });
    }
  }

  Future<void> _block() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showUserPicker(
      context,
      title: l10n.blockSomeone,
      action: l10n.block,
      exclude: {
        for (final peer in _peers ?? const <PrivacyPeer>[])
          if (!peer.isChat) peer.id,
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _error = null);
    try {
      await Future.wait(picked.map(_privacy.block));
    } on Object {
      if (mounted) setState(() => _error = l10n.saveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final peers = [
      for (final peer in _peers ?? const <PrivacyPeer>[])
        if (!_unblocked.contains((peer.isChat, peer.id))) peer,
    ];
    return SettingsPage(
      children: [
        SettingsGroup(
          footer: SettingsFooter(
            _error ?? l10n.blockedUsersAbout,
            error: _error != null,
          ),
          children: [
            SettingsRow(
              key: const ValueKey('block'),
              leading: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MgDestructive.color.withValues(alpha: 0.12),
                ),
                child: const MgIcon(
                  blockedIcon,
                  size: 16,
                  stroke: 2.1,
                  color: MgDestructive.color,
                ),
              ),
              title: l10n.blockSomeone,
              onTap: () => unawaited(_block()),
            ),
            for (final peer in peers)
              SettingsRow(
                key: ValueKey((peer.isChat, peer.id)),
                leading: SenderAvatar(
                  name: peer.name,
                  size: 30,
                  photo: peer.photo,
                ),
                title: peer.name,
                subtitle: peer.isBot ? l10n.folderBot : null,
                trailing: SettingsButton(
                  label: l10n.unblock,
                  onPressed: () => unawaited(_unblock(peer)),
                ),
              ),
            if (_hasMore)
              SettingsRow(
                key: const ValueKey('more'),
                title: l10n.blockedShowMore,
                trailing: _loading ? const SettingsSpinner() : null,
                onTap: () => unawaited(_load(more: true)),
              ),
          ],
        ),
        if (_peers == null && _loading)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Center(child: SettingsSpinner()),
          ),
        if (_peers != null && peers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                l10n.blockedUsersEmpty,
                style: mgTextStyle(c, color: c.fg2),
              ),
            ),
          ),
      ],
    );
  }
}
