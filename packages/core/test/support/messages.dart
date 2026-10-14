import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// A TDLib message with every field the tests don't care about filled in.
td.Message tdMessage({
  required int id,
  required int chatId,
  String text = '',
  td.MessageContent? content,
  bool isOutgoing = true,
  td.MessageSendingState? sendingState,
  td.MessageReplyTo? replyTo,
  int senderUserId = 1,
}) => td.Message(
  id: id,
  sendingState: sendingState,
  senderId: td.MessageSenderUser(userId: senderUserId),
  chatId: chatId,
  isOutgoing: isOutgoing,
  isPinned: false,
  isFromOffline: false,
  canBeSaved: true,
  hasTimestampedMedia: false,
  isChannelPost: false,
  isPaidStarSuggestedPost: false,
  isPaidGramSuggestedPost: false,
  containsUnreadMention: false,
  containsUnreadPollVotes: false,
  date: id,
  editDate: 0,
  unreadReactions: const [],
  replyTo: replyTo,
  selfDestructIn: 0,
  autoDeleteIn: 0,
  viaBotUserId: 0,
  senderBusinessBotUserId: 0,
  senderBoostCount: 0,
  senderTag: '',
  paidMessageStarCount: 0,
  authorSignature: '',
  mediaAlbumId: 0,
  effectId: 0,
  summaryLanguageCode: '',
  content:
      content ??
      td.MessageText(
        text: td.FormattedText(text: text, entities: const []),
      ),
  ephemeralMessageId: 0,
  chatInstance: 0,
);

/// A text message as the store holds it.
ConversationMessage textMessage({
  required int id,
  required int chatId,
  required String text,
  bool isOutgoing = false,
}) => ConversationMessage(
  tdMessage(id: id, chatId: chatId, text: text, isOutgoing: isOutgoing),
);
