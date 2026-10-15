/// On-device language detection for `text.detectLanguage`.
///
/// Deliberately small: the script decides most languages, letters unique
/// to a language split the Cyrillic ones, and common short words split the
/// Latin ones. Text it is unsure about gets null rather than a guess.
library;

/// The language of [text] as an ISO 639-1 code, with a confidence from 0
/// to 1, or null when the text has too few letters to tell.
({String language, double confidence})? detectLanguage(String text) {
  final counts = <_Script, int>{};
  var letters = 0;
  for (final rune in text.runes) {
    final script = _scriptOf(rune);
    if (script == null) continue;
    letters++;
    counts[script] = (counts[script] ?? 0) + 1;
  }
  if (letters < 3) return null;
  final (script, count) = counts.entries
      .map((e) => (e.key, e.value))
      .reduce((a, b) => a.$2 >= b.$2 ? a : b);
  final share = count / letters;
  final lower = text.toLowerCase();
  final _Guess? guess = switch (script) {
    _Script.latin => _latin(lower),
    _Script.cyrillic => _cyrillic(lower),
    _Script.arabic => (RegExp('[پچژگکی]').hasMatch(text) ? 'fa' : 'ar', 0.9),
    // Kana only appears in Japanese; Han alone is taken as Chinese.
    _Script.han || _Script.kana =>
      counts.containsKey(_Script.kana) ? ('ja', 1.0) : ('zh', 0.9),
    _Script.hangul => ('ko', 1.0),
    _Script.greek => ('el', 1.0),
    _Script.hebrew => ('he', 1.0),
    _Script.devanagari => ('hi', 0.9),
    _Script.thai => ('th', 1.0),
    _Script.georgian => ('ka', 1.0),
    _Script.armenian => ('hy', 1.0),
  };
  if (guess == null) return null;
  // Japanese mixes kana with Han: both count as its script.
  final own = script == _Script.han || script == _Script.kana
      ? ((counts[_Script.han] ?? 0) + (counts[_Script.kana] ?? 0)) / letters
      : share;
  return (language: guess.$1, confidence: own * guess.$2);
}

enum _Script {
  latin,
  cyrillic,
  greek,
  arabic,
  hebrew,
  devanagari,
  thai,
  georgian,
  armenian,
  hangul,
  kana,
  han,
}

_Script? _scriptOf(int r) => switch (r) {
  >= 0x41 && <= 0x5A || >= 0x61 && <= 0x7A => _Script.latin,
  >= 0xC0 && <= 0x24F when r != 0xD7 && r != 0xF7 => _Script.latin,
  >= 0x400 && <= 0x4FF => _Script.cyrillic,
  >= 0x370 && <= 0x3FF => _Script.greek,
  >= 0x5D0 && <= 0x5EA => _Script.hebrew,
  >= 0x620 && <= 0x6FF => _Script.arabic,
  >= 0x900 && <= 0x97F => _Script.devanagari,
  >= 0xE00 && <= 0xE7F => _Script.thai,
  >= 0x10A0 && <= 0x10FF => _Script.georgian,
  >= 0x530 && <= 0x58F => _Script.armenian,
  >= 0xAC00 && <= 0xD7AF || >= 0x1100 && <= 0x11FF => _Script.hangul,
  >= 0x3040 && <= 0x30FF => _Script.kana,
  >= 0x4E00 && <= 0x9FFF || >= 0x3400 && <= 0x4DBF => _Script.han,
  _ => null,
};

// Records of (language, how sure the rule is), so the script's share and
// the rule both lower the confidence.
typedef _Guess = (String, double);

_Guess? _cyrillic(String s) {
  if (RegExp('[әғқңөұ]').hasMatch(s)) {
    return ('kk', 0.9);
  }
  if (s.contains('ў')) return ('be', 0.9);
  if (RegExp('[їєґ]').hasMatch(s)) return ('uk', 0.9);
  // "і" without "ї", "є" or "ґ": Ukrainian or Belarusian; "ы" and "ё"
  // are not used in Ukrainian.
  if (s.contains('і')) {
    return RegExp('[ыё]').hasMatch(s) ? ('be', 0.8) : ('uk', 0.7);
  }
  return ('ru', 0.95);
}

// The most common short words of each language, space-separated.
const _wordLists = {
  'en': 'the and is are you that it of to in for with this have not what was be on my',
  'de': 'der die das und ist nicht ich du sie mit ein eine zu auf für es wir auch den sind',
  'es': 'el la los las que y es en de un una por con para no muy pero está como yo',
  'fr': 'le la les et est une un des je vous pas que qui dans pour avec sur ce il nous',
  'it': 'il lo la gli che è non per una un con sono di mi ma anche questo ho come del',
  'pt': 'o os que não é um uma para com eu você em do da mas muito isso está por se',
  'nl': 'de het een en is niet ik je van dat met op voor zijn maar ook wat er we naar',
  'pl':
      'i w nie się na jest to że z do jak ale co tak czy ja mnie jestem już ty',
  'tr': 've bir bu da de ne ben sen için çok ama mi var yok gibi daha olarak değil şey evet',
};

final _words = {
  for (final MapEntry(:key, :value) in _wordLists.entries)
    key: value.split(' ').toSet(),
};

final _wordPattern = RegExp(r"[\p{L}']+", unicode: true);

_Guess? _latin(String s) {
  final words = _wordPattern.allMatches(s).map((m) => m.group(0)!).toList();
  if (words.isEmpty) return null;
  final scores = {for (final l in _words.keys) l: 0.0};
  for (final w in words) {
    for (final MapEntry(key: l, value: list) in _words.entries) {
      if (list.contains(w)) scores[l] = scores[l]! + 1;
    }
  }
  // Letters only some languages use tip close calls.
  void hint(String letters, String language) {
    if (RegExp('[$letters]').hasMatch(s)) {
      scores[language] = scores[language]! + 1.5;
    }
  }

  hint('äöüß', 'de');
  hint('ñ¿¡', 'es');
  hint('çœêèàù', 'fr');
  hint('ãõ', 'pt');
  hint('ąćęłńśźż', 'pl');
  hint('ğışİ', 'tr');
  final ranked = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final best = ranked[0], second = ranked[1];
  if (best.value < 2) return null;
  // A clear lead over the runner-up, and enough of the words recognized.
  final lead = (best.value - second.value) / best.value;
  final coverage = (best.value / words.length).clamp(0, 1) * 2;
  final sure = (0.5 + lead / 2) * coverage.clamp(0, 1);
  return (best.key, sure.toDouble());
}
