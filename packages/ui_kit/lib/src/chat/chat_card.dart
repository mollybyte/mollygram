import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import '../theme/tokens.dart';

/// The card a conversation lies on: a solid [MgColors.card] sheet with
/// rounded corners and a soft shadow, raised over the window frame. Its
/// [child] is clipped to the corners; [background] lies under it (the app
/// puts the user's own wallpaper picture there).
class ChatCard extends StatelessWidget {
  const ChatCard({super.key, required this.child, this.background});

  final Widget child;
  final Widget? background;

  static const double radius = MgRadius.card;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: c.isDark
            ? [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: cssBlur(2),
                  offset: Offset(0, 1),
                ),
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: cssBlur(30),
                  offset: Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Color(0x0F281450),
                  blurRadius: cssBlur(2),
                  offset: Offset(0, 1),
                ),
                BoxShadow(
                  color: Color(0x1A281450),
                  blurRadius: cssBlur(28),
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: ColoredBox(
          color: c.card,
          child: Stack(fit: StackFit.expand, children: [?background, child]),
        ),
      ),
    );
  }
}
