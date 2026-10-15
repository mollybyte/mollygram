import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Messages that panels outside a chat's view asked it to scroll to, by
/// chat: "Show in chat" in the shared media list puts one here and the
/// chat's view takes it, now or as soon as it opens.
final messageJumpProvider =
    NotifierProvider<MessageJumps, Map<int, MessageJump>>(MessageJumps.new);

/// One request; [seq] tells two requests for the same message apart, so
/// asking again scrolls again.
typedef MessageJump = ({int messageId, int seq});

class MessageJumps extends Notifier<Map<int, MessageJump>> {
  var _seq = 0;

  @override
  Map<int, MessageJump> build() => const {};

  /// Asks the view of [chatId] to show [messageId].
  void request(int chatId, int messageId) =>
      state = {...state, chatId: (messageId: messageId, seq: ++_seq)};

  /// The message waiting for [chatId], if any, which no longer waits.
  int? take(int chatId) {
    final jump = state[chatId];
    if (jump == null) return null;
    state = {...state}..remove(chatId);
    return jump.messageId;
  }
}
