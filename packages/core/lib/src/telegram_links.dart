/// Turns what the user clicked into a URL and tells Telegram links from the
/// rest, without asking TDLib.
abstract final class TelegramLinks {
  /// Hosts whose links TDLib understands (`getInternalLinkType`).
  static const hosts = {'t.me', 'telegram.me', 'telegram.dog'};

  static final _username = RegExp(r'^[A-Za-z0-9_]{1,32}$');

  /// A URL for [raw]: `@name` becomes `https://t.me/name`, and a link
  /// without a scheme ("t.me/durov", "example.com/a") gets https. Returns
  /// null for text that is not a link.
  static Uri? normalize(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('@')) {
      final name = text.substring(1);
      return _username.hasMatch(name) ? Uri.https('t.me', '/$name') : null;
    }
    final parsed = Uri.tryParse(text);
    if (parsed == null) return null;
    // "example.com:8080/x" parses with the host as the scheme.
    if (parsed.hasScheme && (parsed.hasAuthority || !_looksLikeHost(text))) {
      return parsed;
    }
    // Words are not a link; "tel:+1 555 0100" with a scheme still is.
    if (text.contains(RegExp(r'\s'))) return null;
    final withScheme = Uri.tryParse('https://$text');
    if (withScheme == null || withScheme.host.isEmpty) return null;
    return withScheme;
  }

  static bool _looksLikeHost(String text) =>
      RegExp(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+:\d').hasMatch(text);

  /// Whether TDLib should resolve [uri]: `tg:` links and links to t.me,
  /// telegram.me, telegram.dog and username subdomains such as
  /// `durov.t.me`.
  static bool isTelegram(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'tg') return true;
    if (scheme != 'http' && scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    final bare = host.startsWith('www.') ? host.substring(4) : host;
    if (hosts.contains(bare)) return true;
    return bare.endsWith('.t.me');
  }

  /// Whether [uri] can be handed to the system: web pages, mail and phone
  /// numbers. Anything else (`file:`, `javascript:`, app schemes) is not
  /// opened from a message.
  static bool isExternal(Uri uri) => const {
    'http',
    'https',
    'mailto',
    'tel',
  }.contains(uri.scheme.toLowerCase());

  static final _hashtag = RegExp(r'^[#$][^\s#$/@]+(@[A-Za-z0-9_]+)?$');
  static final _botCommand = RegExp(r'^/[A-Za-z0-9_]{1,64}(@[A-Za-z0-9_]+)?$');

  /// The hashtag or cashtag [raw] is, such as `#news` or `$TON`; null for
  /// anything else.
  static String? hashtag(String raw) {
    final text = raw.trim();
    return _hashtag.hasMatch(text) ? text : null;
  }

  /// The bot command [raw] is, such as `/start` or `/help@somebot`; null
  /// for anything else.
  static String? botCommand(String raw) {
    final text = raw.trim();
    return _botCommand.hasMatch(text) ? text : null;
  }

  /// The link that opens the private chat with user [userId], as a
  /// mention by name in a message points to it.
  static Uri userLink(int userId) =>
      Uri(scheme: 'tg', host: 'user', queryParameters: {'id': '$userId'});

  /// The user a `tg://user?id=` link points to; null for other links.
  static int? userIdOf(Uri uri) {
    if (uri.scheme.toLowerCase() != 'tg' || uri.host.toLowerCase() != 'user') {
      return null;
    }
    final id = int.tryParse(uri.queryParameters['id'] ?? '');
    return id != null && id > 0 ? id : null;
  }

  /// `t.me/s/name` and `t.me/s/name/123`, the web preview of a channel, as
  /// the link to the channel itself; other links stay as they are.
  static Uri withoutWebPreview(Uri uri) {
    if (!isTelegram(uri) || uri.scheme.toLowerCase() == 'tg') return uri;
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments.first != 's') return uri;
    if (!_username.hasMatch(segments[1])) return uri;
    return uri.replace(pathSegments: segments.skip(1).toList());
  }
}
