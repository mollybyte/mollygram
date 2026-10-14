import 'package:flutter/widgets.dart';

import 'theme/colors.dart';

/// Up to two letters for a monogram: the first letters of the first two
/// words, or the first letter of a single word. Emoji and other symbols
/// count as letters, whole grapheme clusters are kept.
String monogramOf(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  String first(String w) => w.characters.first.toUpperCase();
  if (words.length == 1) return first(words.first);
  return first(words[0]) + first(words[1]);
}

/// A gray monogram avatar. Avatars are never colorful; a photo, when the app
/// has one, replaces the monogram.
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({
    super.key,
    required this.name,
    required this.size,
    this.image,
  });

  /// The chat or user name; its [monogramOf] is drawn.
  final String name;
  final double size;

  /// A photo drawn instead of the monogram.
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.avatarTop, c.avatarBottom],
          ),
          image: image == null
              ? null
              : DecorationImage(image: image!, fit: BoxFit.cover),
        ),
        child: image != null
            ? null
            : Text(
                monogramOf(name),
                maxLines: 1,
                style: TextStyle(
                  color: const Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w600,
                  fontSize: size * 0.36,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
      ),
    );
  }
}
