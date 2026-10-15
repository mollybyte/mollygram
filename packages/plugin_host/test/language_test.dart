import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

void main() {
  test('tells common languages apart', () {
    const samples = {
      'en': 'Are you coming to the meeting with us this evening?',
      'ru': 'Привет, как дела? Давно не виделись с тобой.',
      'uk': 'Привіт, як справи? Давно не бачились з тобою, друже.',
      'de': 'Ich weiß nicht, ob wir heute auch mit dir kommen.',
      'es': 'No sé si podemos ir con ellos a la playa, pero está bien.',
      'fr': 'Je ne sais pas si nous pouvons venir avec vous ce soir.',
      'it': 'Non lo so, ma anche questo è un problema per me.',
      'pt': 'Eu não sei se você está em casa, mas isso é muito bom.',
      'pl': 'Nie wiem, czy to jest dobry pomysł, ale już jestem w domu.',
      'tr': 'Bu akşam çok yorgunum ama yarın gelmek için hazırım.',
      'zh': '你好，我们明天一起去吃饭吧。',
      'ja': 'こんにちは、明日一緒にご飯を食べに行きましょう。',
      'ko': '안녕하세요, 내일 같이 밥 먹으러 가요.',
      'ar': 'مرحبا، كيف حالك اليوم يا صديقي؟',
      'he': 'שלום, מה שלומך היום חבר שלי?',
      'el': 'Γεια σου, τι κάνεις σήμερα φίλε μου;',
    };
    for (final MapEntry(key: language, value: text) in samples.entries) {
      final r = detectLanguage(text);
      expect(r?.language, language, reason: text);
      expect(r!.confidence, greaterThanOrEqualTo(0.6), reason: text);
    }
  });

  test('is unsure rather than wrong', () {
    expect(detectLanguage('ok'), isNull);
    expect(detectLanguage('123 456 !!!'), isNull);
    // Latin letters but no word it knows.
    expect(detectLanguage('Xqzt vlorp grabnik'), isNull);
    final mixed = detectLanguage('ok привет hello мир yes');
    expect(mixed == null || mixed.confidence < 0.6, isTrue);
  });
}
