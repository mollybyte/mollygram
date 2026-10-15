import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';

/// Short and eased, like a macOS sheet; the window is not dimmed.
const _transition = Duration(milliseconds: 160);

Future<T?> _showSheet<T>(BuildContext context, Widget sheet) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0x00000000),
      transitionDuration: _transition,
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, _) => Material(
        type: MaterialType.transparency,
        child: Center(child: sheet),
      ),
    );

/// Asks whether to join the chat of [preview]. Completes with the chat to
/// open: the joined one, or the public one the user chose to look at; null
/// when cancelled or when only a join request went out.
Future<int?> showJoinSheet(
  BuildContext context, {
  required ChatJoinPreview preview,
  required Future<JoinResult> Function() join,
}) => _showSheet<int>(context, JoinSheet(preview: preview, join: join));

/// A one-line notice with a Done button, for links that lead nowhere.
Future<void> showLinkNoticeSheet(BuildContext context, String message) =>
    _showSheet<void>(context, _NoticeSheet(message: message));

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
        Navigator.of(context).pop(chatId);
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

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _join,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _join,
      },
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: JoinSheet.width,
          child: Glass(
            radius: 14,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: MonogramAvatar(name: p.title, size: 64)),
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      if (p.canPreview)
                        MgTextButton(
                          label: p.isChannel
                              ? l10n.linkViewChannel
                              : l10n.linkViewGroup,
                          onPressed: () => Navigator.of(context).pop(p.chatId),
                        ),
                    ],
                  ),
                ],
              ],
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
            radius: 14,
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
