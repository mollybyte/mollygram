import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import 'theme/colors.dart';
import 'theme/theme.dart';

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

/// A round avatar: the gray monogram, or a photo over it.
///
/// Avatars are never colorful. While a photo is on its way, the blurred
/// [placeholder] (Telegram's minithumbnail) covers the monogram, so a chat
/// with a photo never shows letters first. A photo that is already decoded
/// draws at once; one decoded now fades in, so nothing pops while a list
/// scrolls.
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({
    super.key,
    required this.name,
    required this.size,
    this.image,
    this.placeholder,
  });

  /// The chat or user name; its [monogramOf] is drawn.
  final String name;
  final double size;

  /// A photo drawn instead of the monogram.
  final ImageProvider? image;

  /// A tiny preview of [image], drawn blurred until the photo is decoded.
  final ImageProvider? placeholder;

  /// How long a freshly decoded photo takes to appear.
  static const fadeDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final image = this.image;
    final placeholder = this.placeholder;
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
        ),
        child: image == null && placeholder == null
            ? _Monogram(name: name, size: size)
            : ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (placeholder != null)
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: size / 10,
                          sigmaY: size / 10,
                          tileMode: TileMode.clamp,
                        ),
                        child: Image(
                          image: placeholder,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          excludeFromSemantics: true,
                        ),
                      ),
                    if (image != null)
                      Image(
                        image: image,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                        frameBuilder: _fadeIn,
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  static Widget _fadeIn(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: fadeDuration,
      curve: Curves.easeOut,
      child: child,
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    monogramOf(name),
    maxLines: 1,
    style: TextStyle(
      fontFamily: mgFontFamily,
      fontFamilyFallback: mgFontFamilyFallback,
      color: const Color(0xFFFFFFFF),
      fontWeight: MgWeight.medium,
      fontSize: (size * 0.34).roundToDouble(),
      height: 1,
      letterSpacing: size * 0.34 >= 16 ? -0.2 : 0,
    ),
  );
}
