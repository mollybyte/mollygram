import 'package:flutter/widgets.dart';

import 'icons.dart';
import 'theme/colors.dart';
import 'theme/theme.dart';
import 'theme/tokens.dart';

/// A calm note for an empty place, such as a pane with no chat open or a
/// chat with no messages: an optional quiet glyph over one line of
/// secondary text. No pill and no dark fill: an empty place should read as
/// rest, not as an alert.
class MgEmptyState extends StatelessWidget {
  const MgEmptyState(this.text, {super.key, this.icon});

  final String text;
  final MgIconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            MgIcon(icon!, size: 28, color: c.quiet),
            const SizedBox(height: MgSpace.ml),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: mgTextStyle(
              c,
              size: MgType.small,
              weight: MgWeight.medium,
              color: c.fg2,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
