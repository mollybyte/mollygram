import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Messages that panels outside a chat's view asked it to scroll to, by
/// chat: "Show in chat" in the shared media list puts one here and the
/// chat's view takes it, now or as soon as it opens.
final messageJumpProvider =
    NotifierProvider<MessageJumps, Map<int, MessageJump>>(MessageJumps.new);

/// One request; [seq] tells two requests for the same message apart, so
/// asking again scrolls again. [at] is when it was asked.
typedef MessageJump = ({int messageId, int seq, DateTime at});

class MessageJumps extends Notifier<Map<int, MessageJump>> {
  MessageJumps({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// How long a request waits for its chat to open. A chat that did not
  /// open by then should not jump when the user opens it later.
  static const maxWait = Duration(seconds: 10);

  final DateTime Function() _clock;
  var _seq = 0;

  @override
  Map<int, MessageJump> build() => const {};

  /// Asks the view of [chatId] to show [messageId].
  void request(int chatId, int messageId) => state = {
    ...state,
    chatId: (messageId: messageId, seq: ++_seq, at: _clock()),
  };

  /// The message waiting for [chatId], if any, which no longer waits.
  /// Null too when it waited longer than [maxWait].
  int? take(int chatId) {
    final jump = state[chatId];
    if (jump == null) return null;
    state = {...state}..remove(chatId);
    if (_clock().difference(jump.at) > maxWait) return null;
    return jump.messageId;
  }
}
