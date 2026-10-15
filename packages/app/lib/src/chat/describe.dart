import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import '../../l10n/app_localizations.dart';

/// "0:07", "12:30", "1:02:03".
String formatDuration(int seconds) {
  if (seconds < 0) seconds = 0;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}

/// "812 B", "4.2 MB" in the user's language.
String formatFileSize(AppLocalizations l10n, int bytes, String locale) {
  if (bytes < 1024) return l10n.fileSizeBytes('$bytes');
  final units = [l10n.fileSizeKb, l10n.fileSizeMb, l10n.fileSizeGb];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value < 10 ? 1 : 0;
  final number = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: digits,
  ).format(value);
  return units[unit](number);
}

/// The display name of [sender], or a placeholder while TDLib hasn't sent
/// it.
String nameOfSender(
  AppLocalizations l10n,
  ConversationStore store,
  MessageSenderId sender,
) {
  final name = store.nameOf(sender);
  return name == null || name.isEmpty ? l10n.unknownSender : name;
}

/// Where a forwarded message came from.
String forwardOriginName(
  AppLocalizations l10n,
  ConversationStore store,
  td.MessageOrigin origin,
) => switch (origin) {
  td.MessageOriginUser(:final senderUserId) => nameOfSender(
    l10n,
    store,
    MessageSenderId.user(senderUserId),
  ),
  td.MessageOriginHiddenUser(:final senderName) =>
    senderName.isEmpty ? l10n.hiddenAccount : senderName,
  td.MessageOriginChat(:final senderChatId, :final authorSignature) => _signed(
    nameOfSender(l10n, store, MessageSenderId.chat(senderChatId)),
    authorSignature,
  ),
  td.MessageOriginChannel(:final chatId, :final authorSignature) => _signed(
    nameOfSender(l10n, store, MessageSenderId.chat(chatId)),
    authorSignature,
  ),
};

/// Who a forward came from, when Telegram says.
MessageSenderId? originSender(td.MessageOrigin origin) => switch (origin) {
  td.MessageOriginUser(:final senderUserId) => MessageSenderId.user(
    senderUserId,
  ),
  td.MessageOriginChat(:final senderChatId) => MessageSenderId.chat(
    senderChatId,
  ),
  td.MessageOriginChannel(:final chatId) => MessageSenderId.chat(chatId),
  td.MessageOriginHiddenUser() => null,
};

String _signed(String name, String signature) =>
    signature.isEmpty ? name : '$name ($signature)';

/// One line about a message for reply headers and pinned messages: its
/// text, or the kind of media with the caption.
String describeContent(AppLocalizations l10n, td.MessageContent content) {
  final caption = captionOf(content)?.text.replaceAll('\n', ' ') ?? '';
  final label = switch (content) {
    td.MessageText() => '',
    td.MessagePhoto() => l10n.previewPhoto,
    td.MessageVideo() => l10n.previewVideo,
    td.MessageAnimation() => l10n.previewAnimation,
    td.MessageVoiceNote() => l10n.previewVoiceNote,
    td.MessageVideoNote() => l10n.previewVideoNote,
    td.MessageAudio(:final audio) =>
      audio.title.isNotEmpty ? audio.title : l10n.previewAudio,
    td.MessageDocument(:final document) =>
      document.fileName.isNotEmpty ? document.fileName : l10n.previewDocument,
    td.MessageSticker(:final sticker) =>
      '${sticker.emoji} ${l10n.previewSticker}'.trim(),
    td.MessageAnimatedEmoji(:final emoji) => emoji,
    td.MessageDice(:final emoji) => emoji,
    td.MessageLocation() || td.MessageVenue() => l10n.contentLocation,
    td.MessageLiveLocation() => l10n.contentLiveLocation,
    td.MessageContact() => l10n.contentContact,
    td.MessagePoll(:final poll) => '📊 ${poll.question.text}',
    td.MessageGame(:final game) => '🎮 ${game.title}',
    td.MessageInvoice() => l10n.contentInvoice,
    td.MessageStory() => l10n.contentStory,
    td.MessageChecklist() => l10n.contentChecklist,
    td.MessagePaidMedia() => l10n.contentPaidMedia,
    td.MessageCall() => l10n.callOutgoing,
    _ => l10n.previewOther,
  };
  if (label.isEmpty) return caption;
  if (caption.isEmpty) return label;
  return '$label, $caption';
}

/// The sentence of a chat event, such as "Anna joined the group".
String describeService(
  AppLocalizations l10n,
  ConversationStore store,
  ConversationMessage message, {
  required bool isChannel,
}) {
  final content = message.content;
  final actor = nameOfSender(l10n, store, message.sender);
  String user(int id) => nameOfSender(l10n, store, MessageSenderId.user(id));
  String users(List<int> ids) => ids.map(user).join(l10n.listSeparator);
  return switch (content) {
    td.MessageBasicGroupChatCreate(:final title) ||
    td.MessageSupergroupChatCreate(
      :final title,
    ) when !isChannel => l10n.serviceGroupCreated(actor, title),
    td.MessageSupergroupChatCreate() => l10n.serviceChannelCreated,
    td.MessageChatChangeTitle(:final title) =>
      isChannel
          ? l10n.serviceChannelTitleChanged(title)
          : l10n.serviceTitleChanged(actor, title),
    td.MessageChatChangePhoto() =>
      isChannel
          ? l10n.serviceChannelPhotoChanged
          : l10n.servicePhotoChanged(actor),
    td.MessageChatDeletePhoto() =>
      isChannel
          ? l10n.serviceChannelPhotoRemoved
          : l10n.servicePhotoRemoved(actor),
    td.MessageChatAddMembers(:final memberUserIds)
        when memberUserIds.length == 1 &&
            message.sender == MessageSenderId.user(memberUserIds.single) =>
      l10n.serviceJoined(actor),
    td.MessageChatAddMembers(:final memberUserIds) => l10n.serviceAdded(
      actor,
      users(memberUserIds),
    ),
    td.MessageChatJoinByLink() => l10n.serviceJoinedByLink(actor),
    td.MessageChatJoinByRequest() => l10n.serviceJoinedByRequest(actor),
    td.MessageChatDeleteMember(:final userId)
        when message.sender == MessageSenderId.user(userId) =>
      l10n.serviceLeft(actor),
    td.MessageChatDeleteMember(:final userId) => l10n.serviceRemoved(
      actor,
      user(userId),
    ),
    td.MessagePinMessage(:final messageId) => switch (store.message(
      message.chatId,
      messageId,
    )) {
      final pinned? when describeContent(l10n, pinned.content).isNotEmpty =>
        l10n.servicePinned(
          actor,
          _short(describeContent(l10n, pinned.content)),
        ),
      _ => l10n.servicePinnedMessage(actor),
    },
    td.MessageScreenshotTaken() => l10n.serviceScreenshot(actor),
    td.MessageChatSetMessageAutoDeleteTime(:final messageAutoDeleteTime) =>
      messageAutoDeleteTime == 0
          ? l10n.serviceAutoDeleteOff(actor)
          : l10n.serviceAutoDeleteOn(
              actor,
              formatAutoDelete(l10n, messageAutoDeleteTime),
            ),
    td.MessageChatUpgradeTo() ||
    td.MessageChatUpgradeFrom() => l10n.serviceUpgraded,
    td.MessageVideoChatStarted() => l10n.serviceVideoChatStarted(actor),
    td.MessageVideoChatEnded(:final duration) => l10n.serviceVideoChatEnded(
      formatDuration(duration),
    ),
    td.MessageVideoChatScheduled() => l10n.serviceVideoChatScheduled,
    td.MessageInviteVideoChatParticipants(:final userIds) =>
      l10n.serviceVideoChatInvited(actor, users(userIds)),
    td.MessageForumTopicCreated(:final name) => l10n.serviceTopicCreated(name),
    td.MessageForumTopicEdited() ||
    td.MessageForumTopicIsClosedToggled() ||
    td.MessageForumTopicIsHiddenToggled() => l10n.serviceTopicEdited(actor),
    td.MessageContactRegistered() => l10n.serviceContactJoined(actor),
    td.MessageChatSetTheme() => l10n.serviceThemeChanged(actor),
    td.MessageChatSetBackground() => l10n.serviceBackgroundChanged(actor),
    td.MessageGift() ||
    td.MessageUpgradedGift() ||
    td.MessageGiftedPremium() ||
    td.MessageGiftedStars() ||
    td.MessagePremiumGiftCode() => l10n.serviceGift(actor),
    td.MessagePaymentSuccessful() ||
    td.MessagePaymentSuccessfulBot() => l10n.servicePayment,
    td.MessageChatBoost() => l10n.serviceBoost(actor),
    td.MessageGameScore(:final score) => l10n.serviceGameScore(actor, score),
    td.MessageCustomServiceAction(:final text) => text,
    _ => l10n.serviceOther(actor),
  };
}

/// "1 day", "1 week": the auto-delete timer in its largest whole unit.
String formatAutoDelete(AppLocalizations l10n, int seconds) {
  const hour = 3600;
  const day = 24 * hour;
  if (seconds >= 30 * day && seconds % (30 * day) == 0) {
    return l10n.durationMonths(seconds ~/ (30 * day));
  }
  if (seconds >= 7 * day && seconds % (7 * day) == 0) {
    return l10n.durationWeeks(seconds ~/ (7 * day));
  }
  if (seconds >= day && seconds % day == 0) {
    return l10n.durationDays(seconds ~/ day);
  }
  if (seconds >= hour && seconds % hour == 0) {
    return l10n.durationHours(seconds ~/ hour);
  }
  return l10n.durationMinutes((seconds / 60).ceil());
}

String _short(String text) =>
    text.length <= 40 ? text : '${text.substring(0, 39).trimRight()}…';
