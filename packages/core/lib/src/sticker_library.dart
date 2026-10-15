import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// The user's stickers and Telegram's emoji keywords, for the emoji and
/// sticker panel. TDLib keeps all of it in its database, so asking again
/// each time the panel opens is cheap and never stale.
final class StickerLibrary {
  StickerLibrary(this._client);

  final td.TdClient _client;

  /// Installed sticker sets, in the order the user arranged them.
  Future<List<td.StickerSetInfo>> installedSets() async {
    final sets = await _client.send(
      const td.GetInstalledStickerSets(stickerType: td.StickerTypeRegular()),
    );
    return sets.sets;
  }

  /// Installed custom emoji sets, in the order the user arranged them.
  Future<List<td.StickerSetInfo>> installedEmojiSets() async {
    final sets = await _client.send(
      const td.GetInstalledStickerSets(
        stickerType: td.StickerTypeCustomEmoji(),
      ),
    );
    return sets.sets;
  }

  /// Every sticker of a set.
  Future<List<td.Sticker>> setStickers(int setId) async =>
      (await _client.send(td.GetStickerSet(setId: setId))).stickers;

  /// Recently sent stickers, newest first.
  Future<List<td.Sticker>> recent() async =>
      (await _client.send(const td.GetRecentStickers(isAttached: false)))
          .stickers;

  Future<List<td.Sticker>> favorites() async =>
      (await _client.send(const td.GetFavoriteStickers())).stickers;

  /// The user's saved GIFs, newest first, for the panel's GIF tab.
  Future<List<td.Animation>> savedAnimations() async =>
      (await _client.send(const td.GetSavedAnimations())).animations;

  /// Emoji whose Telegram keywords start with [query], each with the
  /// keyword that matched, best matches first and no emoji twice.
  Future<List<({String emoji, String keyword})>> emojiSuggestions(
    String query, {
    List<String> languages = const ['en'],
  }) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    final found = await _client.send(
      td.SearchEmojis(text: text, inputLanguageCodes: languages),
    );
    final seen = <String>{};
    return [
      for (final keyword in found.emojiKeywords)
        if (seen.add(keyword.emoji))
          (emoji: keyword.emoji, keyword: keyword.keyword),
    ];
  }

  /// Stickers that stand for [emoji], from the installed sets and the
  /// recent ones, for the strip above the composer.
  Future<List<td.Sticker>> stickersFor(String emoji, {int chatId = 0}) async =>
      (await _client.send(
        td.GetStickers(
          stickerType: const td.StickerTypeRegular(),
          query: emoji,
          limit: 24,
          chatId: chatId,
        ),
      )).stickers;

  /// Stickers matching [query], an emoji or a word in the given
  /// languages: from the installed and recent ones first, then the rest
  /// Telegram knows, as the panel's search shows them.
  Future<List<td.Sticker>> searchStickers(
    String query, {
    List<String> languages = const ['en'],
    int limit = 60,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    final found = await _client.send(
      td.SearchStickers(
        stickerType: const td.StickerTypeRegular(),
        emojis: '',
        query: text,
        inputLanguageCodes: languages,
        offset: 0,
        limit: limit,
      ),
    );
    return found.stickers;
  }

  /// The stickers behind custom emoji, by their ids; unknown ids are
  /// left out.
  Future<List<td.Sticker>> customEmoji(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final found = await _client.send(
      td.GetCustomEmojiStickers(customEmojiIds: ids),
    );
    return found.stickers;
  }

  /// Emoji whose Telegram keywords start with [query], in the given
  /// languages (IETF codes such as `ru`), best matches first.
  Future<List<String>> searchEmoji(
    String query, {
    List<String> languages = const ['en'],
  }) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    final found = await _client.send(
      td.SearchEmojis(text: text, inputLanguageCodes: languages),
    );
    return {for (final keyword in found.emojiKeywords) keyword.emoji}.toList();
  }
}
