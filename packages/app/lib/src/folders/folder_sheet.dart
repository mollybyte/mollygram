import 'package:flutter/material.dart';

/// How long a folder sheet takes to appear, as the other sheets do.
const _transition = Duration(milliseconds: 160);

/// Shows [sheet] centered over the window the way the app's other sheets
/// appear: a short fade and scale, no dimming, closed by a click outside.
Future<T?> showFolderSheet<T>(BuildContext context, Widget sheet) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0x00000000),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _transition,
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, _) => Material(
        type: MaterialType.transparency,
        child: Center(child: sheet),
      ),
    );
