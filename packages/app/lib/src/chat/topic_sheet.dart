import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../profile/manage_sheet.dart';
import '../session/providers.dart';

/// Asks for a topic's name: a new one in forum [chatId], or a new name for
/// [topic].
Future<void> showTopicSheet(
  BuildContext context,
  int chatId, {
  td.ForumTopicInfo? topic,
}) => showManageSheet<void>(context, TopicSheet(chatId: chatId, topic: topic));

class TopicSheet extends ConsumerStatefulWidget {
  const TopicSheet({super.key, required this.chatId, this.topic});

  final int chatId;
  final td.ForumTopicInfo? topic;

  @override
  ConsumerState<TopicSheet> createState() => _TopicSheetState();
}

class _TopicSheetState extends ConsumerState<TopicSheet> {
  late final _name = TextEditingController(text: widget.topic?.name ?? '');
  var _busy = false;
  var _failed = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = l10n.topicNameRequired);
      return;
    }
    final session = ref.read(telegramSessionProvider).asData?.value;
    if (session == null) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      if (widget.topic case final topic?) {
        await session.conversations.editTopicName(
          widget.chatId,
          topic.forumTopicId,
          name,
        );
      } else {
        await session.conversations.createTopic(widget.chatId, name);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.topic != null;
    return ManageSheetFrame(
      title: editing ? l10n.editTopic : l10n.newTopic,
      action: editing ? l10n.save : l10n.create,
      busy: _busy,
      error: _failed
          ? editing
                ? l10n.topicActionFailed
                : l10n.createFailed
          : null,
      onAction: _busy ? null : () => unawaited(_submit()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: MgUnderlineField(
          controller: _name,
          hintText: l10n.topicName,
          autofocus: true,
          fontSize: 14,
          errorText: _nameError,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
          onSubmitted: (_) => unawaited(_submit()),
        ),
      ),
    );
  }
}
