import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:plugin_host/plugin_host.dart' show detectLanguage;

/// A language's name in English, in Russian as the target of "translate
/// to" and as the source in "translated from".
typedef LanguageNames = ({String en, String ru, String ruFrom});

/// The languages the translation bar can name, by ISO 639-1 code. The
/// device detects these; Telegram translates into most of them.
const translationLanguages = <String, LanguageNames>{
  'en': (en: 'English', ru: 'английский', ruFrom: 'английского'),
  'ru': (en: 'Russian', ru: 'русский', ruFrom: 'русского'),
  'uk': (en: 'Ukrainian', ru: 'украинский', ruFrom: 'украинского'),
  'be': (en: 'Belarusian', ru: 'белорусский', ruFrom: 'белорусского'),
  'de': (en: 'German', ru: 'немецкий', ruFrom: 'немецкого'),
  'es': (en: 'Spanish', ru: 'испанский', ruFrom: 'испанского'),
  'fr': (en: 'French', ru: 'французский', ruFrom: 'французского'),
  'it': (en: 'Italian', ru: 'итальянский', ruFrom: 'итальянского'),
  'pt': (en: 'Portuguese', ru: 'португальский', ruFrom: 'португальского'),
  'pl': (en: 'Polish', ru: 'польский', ruFrom: 'польского'),
  'nl': (en: 'Dutch', ru: 'нидерландский', ruFrom: 'нидерландского'),
  'tr': (en: 'Turkish', ru: 'турецкий', ruFrom: 'турецкого'),
  'ar': (en: 'Arabic', ru: 'арабский', ruFrom: 'арабского'),
  'fa': (en: 'Persian', ru: 'персидский', ruFrom: 'персидского'),
  'he': (en: 'Hebrew', ru: 'иврит', ruFrom: 'иврита'),
  'hi': (en: 'Hindi', ru: 'хинди', ruFrom: 'хинди'),
  'zh': (en: 'Chinese', ru: 'китайский', ruFrom: 'китайского'),
  'ja': (en: 'Japanese', ru: 'японский', ruFrom: 'японского'),
  'ko': (en: 'Korean', ru: 'корейский', ruFrom: 'корейского'),
  'kk': (en: 'Kazakh', ru: 'казахский', ruFrom: 'казахского'),
  'uz': (en: 'Uzbek', ru: 'узбекский', ruFrom: 'узбекского'),
  'el': (en: 'Greek', ru: 'греческий', ruFrom: 'греческого'),
  'th': (en: 'Thai', ru: 'тайский', ruFrom: 'тайского'),
  'ka': (en: 'Georgian', ru: 'грузинский', ruFrom: 'грузинского'),
  'hy': (en: 'Armenian', ru: 'армянский', ruFrom: 'армянского'),
};

/// The languages "Translate to…" offers, the common ones first.
const translateTargets = [
  'en',
  'ru',
  'uk',
  'de',
  'es',
  'fr',
  'it',
  'pt',
  'pl',
  'tr',
  'ar',
  'zh',
  'ja',
  'ko',
];

/// [code] named for the app's language [locale] ('ru' or anything else for
/// English). [from] picks the form after "from"; unknown codes are
/// shown as they are.
String languageName(String code, String locale, {bool from = false}) {
  final names = translationLanguages[code];
  if (names == null) return code;
  if (locale != 'ru') return names.en;
  return from ? names.ruFrom : names.ru;
}

/// Translates one message into the language given.
typedef MessageTranslation = Future<td.FormattedText> Function(
  int chatId,
  int messageId,
  String to,
);

/// The translation of one chat's messages, shown in place of the text.
///
/// Messages are translated as they come on screen, one request each, a few
/// at a time, and only those the device finds to be in another language
/// than the target. The owner sets [to], [skip] and [active]; widgets
/// listen for finished translations.
class ChatTranslation extends ChangeNotifier {
  ChatTranslation(this._translate);

  final MessageTranslation _translate;

  /// The target language code.
  String to = 'en';

  /// Languages left as they are.
  Set<String> skip = const {};

  /// Whether the chat is shown translated.
  bool get active => _active;
  var _active = false;

  /// The language of the chat the last time it was clear; kept for the
  /// bar while it is translated.
  String? language;

  /// A message shorter than this is not translated, as the detector is
  /// unreliable on texts such as "ok" or "lol".
  static const minLength = 12;
  static const minConfidence = 0.6;
  static const _parallel = 3;

  final _done = <int, ({int hash, td.FormattedText text})>{};
  final _pending = <int>{};

  /// Messages Telegram could not translate, so they are not asked again
  /// each time they are built.
  final _failed = <int, int>{};
  final _queue = Queue<ConversationMessage>();
  final _detected = <int, ({int hash, String? code})>{};
  var _inFlight = 0;
  var _generation = 0;
  var _failures = 0;

  /// Called once for each translation that fails, for the owner to tell
  /// the user.
  VoidCallback? onFailure;

  /// Whether a request is on its way and nothing is translated yet.
  bool get working =>
      _active && _done.isEmpty && (_pending.isNotEmpty || _queue.isNotEmpty);

  /// Whether any message is shown translated.
  bool get hasTranslations => _done.isNotEmpty;

  /// Applies the owner's choices. A new target drops the translations
  /// made for the old one; a chat turned off stops asking.
  void configure({
    required String to,
    required Set<String> skip,
    required bool active,
  }) {
    final changed = to != this.to || active != _active;
    this.skip = skip;
    if (to != this.to) {
      this.to = to;
      _forget();
    }
    if (active != _active) {
      _active = active;
      if (!active) _forget();
    }
    // Called while the chat view builds, so tell the messages afterwards.
    if (changed) scheduleMicrotask(_notifyLater);
  }

  var _disposed = false;

  void _notifyLater() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Forgets everything, as the chat on screen changes.
  void reset() {
    _forget();
    _detected.clear();
    language = null;
    _active = false;
  }

  void _forget() {
    _generation++;
    _done.clear();
    _pending.clear();
    _failed.clear();
    _queue.clear();
    _failures = 0;
  }

  static td.FormattedText? _textOf(ConversationMessage message) =>
      message.isDeleted ? null : captionOf(message.message.content);

  /// The language of [message]'s text, or null when the detector isn't
  /// sure or the text is too short. Remembered per message.
  String? languageOf(ConversationMessage message) {
    final text = _textOf(message)?.text;
    if (text == null || text.trim().length < minLength) return null;
    final hash = text.hashCode;
    final known = _detected[message.id];
    if (known != null && known.hash == hash) return known.code;
    final found = detectLanguage(
      text.length > 4000 ? text.substring(0, 4000) : text,
    );
    final code = found != null && found.confidence >= minConfidence
        ? found.language.toLowerCase()
        : null;
    _detected[message.id] = (hash: hash, code: code);
    return code;
  }

  /// The language most of the chat's recent incoming messages are in, or
  /// null when it isn't clear. [newestFirst] is the loaded history.
  String? chatLanguage(List<ConversationMessage> newestFirst) {
    final votes = <String, int>{};
    var total = 0;
    for (final message in newestFirst.take(60)) {
      if (message.message.isOutgoing) continue;
      final code = languageOf(message);
      if (code == null) continue;
      votes[code] = (votes[code] ?? 0) + 1;
      if (++total >= 12) break;
    }
    if (total < 2) return null;
    final top = votes.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (top.value < 2 || top.value / total < 0.6) return null;
    return language = top.key;
  }

  /// [message]'s translation of [original], when the chat is shown
  /// translated and the message has been translated. Asks for it when it
  /// hasn't, so a message that scrolls into view gets translated.
  td.FormattedText? textFor(
    ConversationMessage message,
    td.FormattedText original,
  ) {
    if (!_active) return null;
    final done = _done[message.id];
    if (done != null && done.hash == original.text.hashCode) {
      return done.text;
    }
    _request(message, original);
    return null;
  }

  void _request(ConversationMessage message, td.FormattedText original) {
    if (_pending.contains(message.id) ||
        _failed[message.id] == original.text.hashCode ||
        message.message.isOutgoing) {
      return;
    }
    final code = languageOf(message);
    if (code == null || code == to || skip.contains(code)) return;
    _pending.add(message.id);
    _queue.add(message);
    scheduleMicrotask(_pump);
  }

  void _pump() {
    while (_inFlight < _parallel && _queue.isNotEmpty) {
      final message = _queue.removeFirst();
      final text = _textOf(message);
      if (text == null) {
        _pending.remove(message.id);
        continue;
      }
      _inFlight++;
      unawaited(_translateOne(message, text, _generation));
    }
  }

  Future<void> _translateOne(
    ConversationMessage message,
    td.FormattedText original,
    int generation,
  ) async {
    try {
      final result = await _translate(message.chatId, message.id, to);
      if (generation != _generation) return;
      _done[message.id] = (hash: original.text.hashCode, text: result);
      _pending.remove(message.id);
      _notifyLater();
    } on Object {
      if (generation != _generation) return;
      // Left as written; the owner decides whether to say so.
      _pending.remove(message.id);
      _failed[message.id] = original.text.hashCode;
      if (_failures++ == 0) onFailure?.call();
      _notifyLater();
    } finally {
      _inFlight--;
      if (generation == _generation) _pump();
    }
  }
}

/// Gives the messages under it the translation of their chat.
class ChatTranslationScope extends InheritedNotifier<ChatTranslation> {
  const ChatTranslationScope({
    super.key,
    required ChatTranslation translation,
    required super.child,
  }) : super(notifier: translation);

  static ChatTranslation? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChatTranslationScope>()
      ?.notifier;
}

/// Builds the text of [message] from its translation when the chat is
/// shown translated, and from [text] as written otherwise.
class TranslatedText extends StatelessWidget {
  const TranslatedText({
    super.key,
    required this.message,
    required this.text,
    required this.builder,
  });

  final ConversationMessage message;
  final td.FormattedText text;
  final Widget Function(td.FormattedText text) builder;

  @override
  Widget build(BuildContext context) {
    final translation = ChatTranslationScope.maybeOf(context);
    return builder(translation?.textFor(message, text) ?? text);
  }
}
