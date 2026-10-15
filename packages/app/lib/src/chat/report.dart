import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';

/// Reports [messageIds] of [chatId] the way Telegram for macOS does: the
/// server names the reasons, the user picks one (and then maybe a more
/// precise one), adds details when asked, and a toast says thanks. Stops
/// quietly when the user cancels or leaves the chat ([isShown]).
Future<void> reportMessages(
  BuildContext context, {
  required ConversationController conversations,
  required int chatId,
  required List<int> messageIds,
  required bool Function() isShown,
}) async {
  final l10n = AppLocalizations.of(context);
  Uint8List? optionId;
  var text = '';
  // The server leads: each answer asks for the next step or ends it.
  for (var step = 0; step < 8; step++) {
    final td.ReportChatResult result;
    try {
      result = await conversations.report(
        chatId,
        messageIds,
        optionId: optionId,
        text: text,
      );
    } on Object {
      return;
    }
    if (!context.mounted || !isShown()) return;
    switch (result) {
      case td.ReportChatResultOk():
        showMgToast(context, l10n.reportSent);
        return;
      case td.ReportChatResultOptionRequired(:final title, :final options):
        if (options.isEmpty) return;
        final picked = await showMgChoice(
          context,
          title: title.isEmpty ? l10n.menuReport : title,
          options: [for (final option in options) option.text],
          cancelLabel: l10n.cancel,
        );
        if (picked == null || !context.mounted || !isShown()) return;
        optionId = options[picked].id;
      case td.ReportChatResultTextRequired(
        optionId: final id,
        :final isOptional,
      ):
        final details = await showMgPrompt(
          context,
          title: l10n.reportDetailsTitle,
          message: isOptional ? l10n.reportDetailsOptional : null,
          hint: l10n.reportDetailsHint,
          confirmLabel: l10n.send,
          cancelLabel: l10n.cancel,
          allowEmpty: isOptional,
        );
        if (details == null || !context.mounted || !isShown()) return;
        optionId = id;
        text = details;
      case td.ReportChatResultMessagesRequired():
        // The messages were sent along; nothing more to add.
        return;
    }
  }
}
