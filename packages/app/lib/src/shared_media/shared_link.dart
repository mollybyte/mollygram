import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// A link a message shares, as the Links tab lists it.
final class SharedLink {
  const SharedLink({
    required this.url,
    required this.title,
    required this.description,
  });

  final String url;

  /// The page title from the link preview, or the site's host.
  final String title;

  /// The preview's description, or the message text around the link.
  final String description;
}

/// The first link in [message]: the one its preview shows, else the first
/// link in its text or caption. Null when there is none.
SharedLink? sharedLinkOf(ConversationMessage message) {
  final content = message.content;
  final caption = captionOf(content);
  final preview = content is td.MessageText ? content.linkPreview : null;
  final url = preview?.url ?? _firstUrl(caption);
  if (url == null || url.isEmpty) return null;
  final text = caption?.text.trim() ?? '';
  final title = preview != null && preview.title.isNotEmpty
      ? preview.title
      : preview != null && preview.siteName.isNotEmpty
      ? preview.siteName
      : _host(url);
  final description = preview != null && preview.description.text.isNotEmpty
      ? preview.description.text
      : text == url
      ? ''
      : text;
  return SharedLink(url: url, title: title, description: description);
}

String? _firstUrl(td.FormattedText? text) {
  if (text == null) return null;
  for (final entity in text.entities) {
    switch (entity.type) {
      case td.TextEntityTypeTextUrl(:final url):
        return url;
      case td.TextEntityTypeUrl():
        final end = entity.offset + entity.length;
        if (entity.offset < 0 || end > text.text.length) continue;
        return text.text.substring(entity.offset, end);
      default:
    }
  }
  return null;
}

/// "example.com" for "https://www.example.com/a"; the link itself when it
/// has no host.
String _host(String url) {
  final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
  final host = uri?.host ?? '';
  if (host.isEmpty) return url;
  return host.startsWith('www.') ? host.substring(4) : host;
}
