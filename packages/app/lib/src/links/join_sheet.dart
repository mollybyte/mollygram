import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../avatar/peer_avatar.dart';

/// What the user chose in the join sheet: a chat to open, and whether they
/// joined it or only want to look at it first.
typedef JoinSheetResult = ({int chatId, bool joined});

/// Asks whether to join the chat of [preview]. Completes with the chat to
/// open; null when cancelled or when only a join request went out.
Future<JoinSheetResult?> showJoinSheet(
  BuildContext context, {
  required ChatJoinPreview preview,
  required Future<JoinResult> Function() join,
}) => showMgSheet<JoinSheetResult>(
  context,
  JoinSheet(preview: preview, join: join),
);

/// A one-line notice with a Done button, for links that lead nowhere.
Future<void> showLinkNoticeSheet(BuildContext context, String message) =>
    showMgSheet<void>(context, _NoticeSheet(message: message));

class JoinSheet extends StatefulWidget {
  const JoinSheet({super.key, required this.preview, required this.join});

  final ChatJoinPreview preview;
  final Future<JoinResult> Function() join;

  static const double width = 320;

  @override
  State<JoinSheet> createState() => _JoinSheetState();
}

enum _Stage { asking, joining, requestSent, failed }

class _JoinSheetState extends State<JoinSheet> {
  var _stage = _Stage.asking;

  Future<void> _join() async {
    if (_stage == _Stage.joining) return;
    if (_stage == _Stage.requestSent) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _stage = _Stage.joining);
    final result = await widget.join();
    if (!mounted) return;
    switch (result) {
      case ChatJoined(:final chatId):
        Navigator.of(context).pop((chatId: chatId, joined: true));
      case JoinRequestSent():
        setState(() => _stage = _Stage.requestSent);
      case JoinFailed():
        setState(() => _stage = _Stage.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final p = widget.preview;
    final sent = _stage == _Stage.requestSent;
    final joining = _stage == _Stage.joining;

    final count = p.isChannel
        ? l10n.linkSubscribers(p.memberCount)
        : l10n.linkMembers(p.memberCount);
    final subtitle = [?p.username == null ? null : '@${p.username}', count];

    final String action;
    if (sent) {
      action = l10n.done;
    } else if (p.createsJoinRequest) {
      action = l10n.linkRequestToJoin;
    } else {
      action = p.isChannel ? l10n.linkJoinChannel : l10n.linkJoinGroup;
    }

    final String? note = switch (_stage) {
      _Stage.requestSent => l10n.linkRequestSentHint,
      _Stage.failed => l10n.linkJoinFailed,
      _ when p.createsJoinRequest => l10n.linkApprovalHint,
      _ => null,
    };

    // While the join is on its way the sheet stays, so its answer is not
    // lost: Esc and clicks outside wait for it.
    return PopScope(
      canPop: !joining,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): _join,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): _join,
        },
        child: Focus(
          autofocus: true,
          child: SizedBox(
            width: JoinSheet.width,
            child: Glass(
              radius: MgRadius.popover,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: PeerAvatar.chat(
                      name: p.title,
                      size: 64,
                      photo: p.photo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    sent ? l10n.linkRequestSent : p.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(
                      c,
                      size: 15,
                      weight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sent ? p.title : subtitle.join(' · '),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(c, size: MgType.small, color: c.fg2),
                  ),
                  if (p.description.isNotEmpty && !sent) ...[
                    const SizedBox(height: 10),
                    Text(
                      p.description,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(c),
                    ),
                  ],
                  if (note != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      note,
                      textAlign: TextAlign.center,
                      style: mgTextStyle(
                        c,
                        size: MgType.small,
                        color: _stage == _Stage.failed
                            ? MgDestructive.color
                            : c.fg2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  MgPrimaryButton(
                    label: action,
                    expand: true,
                    loading: _stage == _Stage.joining,
                    onPressed: () => unawaited(_join()),
                  ),
                  if (!sent) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MgTextButton(
                          label: l10n.cancel,
                          onPressed: joining
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                        if (p.canPreview)
                          MgTextButton(
                            label: p.isChannel
                                ? l10n.linkViewChannel
                                : l10n.linkViewGroup,
                            onPressed: joining
                                ? null
                                : () => Navigator.of(context)
                                      .pop((chatId: p.chatId, joined: false)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeSheet extends StatelessWidget {
  const _NoticeSheet({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    void close() => Navigator.of(context).pop();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): close,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): close,
      },
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 280,
          child: Glass(
            radius: MgRadius.popover,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: mgTextStyle(c),
                ),
                const SizedBox(height: 14),
                MgPrimaryButton(
                  label: AppLocalizations.of(context).done,
                  expand: true,
                  onPressed: close,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar over the composer of a group or channel the user is only
/// looking at (View in the join sheet): Join, or close the bar.
class JoinBar extends StatefulWidget {
  const JoinBar({
    super.key,
    required this.preview,
    required this.join,
    required this.onDone,
  });

  final ChatJoinPreview preview;
  final Future<JoinResult> Function() join;

  /// The user joined, sent a request or closed the bar.
  final VoidCallback onDone;

  static const double height = 44;

  @override
  State<JoinBar> createState() => _JoinBarState();
}

class _JoinBarState extends State<JoinBar> {
  var _stage = _Stage.asking;
  Timer? _close;

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  Future<void> _join() async {
    if (_stage == _Stage.joining || _stage == _Stage.requestSent) return;
    setState(() => _stage = _Stage.joining);
    final result = await widget.join();
    if (!mounted) return;
    switch (result) {
      case ChatJoined():
        widget.onDone();
      case JoinRequestSent():
        setState(() => _stage = _Stage.requestSent);
        _close = Timer(const Duration(seconds: 2), widget.onDone);
      case JoinFailed():
        setState(() => _stage = _Stage.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final p = widget.preview;
    final label = switch (_stage) {
      _Stage.requestSent => l10n.linkRequestSent,
      _Stage.failed => l10n.linkJoinFailed,
      _ when p.createsJoinRequest => l10n.linkRequestToJoin,
      _ => p.isChannel ? l10n.linkJoinChannel : l10n.linkJoinGroup,
    };
    final active = _stage == _Stage.asking || _stage == _Stage.failed;
    return SizedBox(
      height: JoinBar.height,
      child: Glass(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            const SizedBox(width: 32),
            Expanded(
              child: Semantics(
                button: active,
                label: label,
                excludeSemantics: true,
                child: MouseRegion(
                  cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: active ? () => unawaited(_join()) : null,
                    child: Center(
                      child: _stage == _Stage.joining
                          ? SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.accent,
                              ),
                            )
                          : Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(
                                c,
                                size: MgType.title,
                                weight: FontWeight.w600,
                                color: switch (_stage) {
                                  _Stage.failed => MgDestructive.color,
                                  _Stage.requestSent => c.fg2,
                                  _ => c.accent,
                                },
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            MgIconButton(
              icon: MgIcons.close,
              tooltip: l10n.close,
              onPressed: _stage == _Stage.joining ? null : widget.onDone,
            ),
          ],
        ),
      ),
    );
  }
}
