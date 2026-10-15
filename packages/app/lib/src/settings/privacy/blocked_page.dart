import 'dart:async';
import 'dart:math';

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
  var _nextOffset = 0;

  /// How many the user has asked to see, counting a page still loading.
  var _wanted = PrivacySettingsController.pageSize;
  var _total = 0;
  var _loading = false;
  String? _error;

  /// Bumped by every load; an answer to an older one is dropped, so a
  /// reload and a "Show more" can't both land.
  var _generation = 0;

  /// Unblocked here and hidden until a load no longer lists them.
  final _unblocked = <(bool, int)>{};
  StreamSubscription<void>? _changes;
  Timer? _reload;

  PrivacySettingsController get _privacy => ref.read(privacyControllerProvider);

  bool get _hasMore => _nextOffset < _total;

  @override
  void initState() {
    super.initState();
    // Blocking here and TDLib's update both report a change: one reload.
    _changes = _privacy.blockedChanges.listen((_) {
      _reload?.cancel();
      _reload = Timer(
        const Duration(milliseconds: 120),
        () => unawaited(_load()),
      );
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _reload?.cancel();
    unawaited(_changes?.cancel());
    super.dispose();
  }

  /// The first page, or the next one with [more]. A reload asks again for
  /// as many as are shown, in TDLib's pages of at most 100, so the list
  /// doesn't fold back to one page.
  Future<void> _load({bool more = false}) async {
    if (more && _loading) return;
    final generation = ++_generation;
    final from = more ? _nextOffset : 0;
    if (more) _wanted = _nextOffset + PrivacySettingsController.pageSize;
    final until = more ? _wanted : max(_wanted, _nextOffset);
    setState(() => _loading = true);
    try {
      final peers = <PrivacyPeer>[];
      var offset = from;
      var total = 0;
      do {
        final page = await _privacy.blocked(
          offset: offset,
          limit: min(until - offset, PrivacySettingsController.maxPageSize),
        );
        if (!mounted || generation != _generation) return;
        peers.addAll(page.peers);
        total = page.totalCount;
        if (page.nextOffset == offset) break;
        offset = page.nextOffset;
      } while (offset < until && offset < total);
      setState(() {
        final all = [if (more) ...?_peers, ...peers];
        final seen = <(bool, int)>{};
        _peers = [
          for (final peer in all)
            if (seen.add((peer.isChat, peer.id))) peer,
        ];
        _unblocked.retainAll(seen);
        _nextOffset = offset;
        _total = total;
        _loading = false;
        _error = null;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
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
    final l10n = AppLocalizations.of(context);
    final peers = [
      for (final peer in _peers ?? const <PrivacyPeer>[])
        if (!_unblocked.contains((peer.isChat, peer.id))) peer,
    ];
    return SettingsPage(
      children: [
        AnimatedSize(
          duration: settingsMotionOf(context),
          curve: settingsCurve,
          alignment: Alignment.topCenter,
          child: SettingsGroup(
            footer: SettingsFooter(
              _error ??
                  (_peers != null && peers.isEmpty && !_hasMore
                      ? '${l10n.blockedUsersEmpty}\n${l10n.blockedUsersAbout}'
                      : l10n.blockedUsersAbout),
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
              if (_hasMore && _peers != null)
                SettingsRow(
                  key: const ValueKey('more'),
                  title: l10n.blockedShowMore,
                  trailing: _loading ? const SettingsSpinner() : null,
                  onTap: () => unawaited(_load(more: true)),
                ),
            ],
          ),
        ),
        if (_peers == null && _loading)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Center(child: SettingsSpinner()),
          ),
      ],
    );
  }
}
