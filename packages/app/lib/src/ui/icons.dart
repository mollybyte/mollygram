import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icons from the mockup (stroke 1.7–2.2, currentColor).
abstract final class MgIcons {
  static const compose =
      '<path d="M12 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-6"/><path d="M17.5 3.5a2.1 2.1 0 0 1 3 3L12 15l-4 1 1-4z"/>';
  static const search =
      '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>';
  static const call =
      '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/>';
  static const ghost =
      '<path d="M6 20V10a6 6 0 0 1 12 0v10l-2-1.5-2 1.5-2-1.5-2 1.5-2-1.5z"/><path d="M10 10h.01M14 10h.01" stroke-width="2.4"/>';
  static const panel =
      '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M15 4v16"/>';
  static const attach =
      '<path d="M21 11.5 12.5 20a5 5 0 0 1-7-7l8.5-8.5a3.3 3.3 0 0 1 4.7 4.7L10.2 17.7a1.7 1.7 0 0 1-2.4-2.4L15.5 7.6"/>';
  static const emoji =
      '<circle cx="12" cy="12" r="9"/><path d="M8.5 14.5a4 4 0 0 0 7 0M9 9.5h.01M15 9.5h.01"/>';
  static const mic =
      '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>';
  static const send = '<path d="M12 19V5M6 11l6-6 6 6"/>';
  static const download = '<path d="M12 5v12M7 12l5 5 5-5"/>';
  static const play =
      '<path d="M7 4.5v15l13-7.5z" fill="currentColor" stroke="none"/>';
}

class MgIcon extends StatelessWidget {
  const MgIcon(this.body, {super.key, this.size = 17, this.stroke = 1.8});

  final String body;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color!;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="currentColor" stroke-width="$stroke" stroke-linecap="round" '
      'stroke-linejoin="round">$body</svg>',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
    );
  }
}
