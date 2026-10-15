import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'privacy_settings.dart';

/// A small ghost in the sidebar's title bar while any privacy extra is
/// on, dimmed unless it is full ghost mode, so none is on by surprise.
/// Clicking it opens the privacy extras.
class GhostModeCapsule extends ConsumerWidget {
  const GhostModeCapsule({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (anyOn, ghost) = ref.watch(
      privacySettingsProvider.select((s) => (s.anyOn, s.isGhost)),
    );
    return GhostModeView(on: anyOn, partial: !ghost, onTap: onTap);
  }
}

/// The ghost capsule itself: fades and scales in when [on], and takes no
/// clicks and no space in the accessibility tree while off. [partial]
/// dims the ghost: some extras are on, not all of them.
class GhostModeView extends StatelessWidget {
  const GhostModeView({
    super.key,
    required this.on,
    this.partial = false,
    this.onTap,
  });

  final bool on;
  final bool partial;
  final VoidCallback? onTap;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _duration;
    final label = partial ? l10n.privacyExtrasAreOn : l10n.ghostModeIsOn;
    // Off, the capsule takes no width, so the search field beside it
    // reaches the compose button.
    return AnimatedAlign(
      alignment: Alignment.center,
      widthFactor: on ? 1 : 0,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        ignoring: !on,
        child: ExcludeSemantics(
          excluding: !on,
          child: AnimatedOpacity(
            opacity: on ? 1 : 0,
            duration: duration,
            curve: Curves.easeOut,
            child: AnimatedScale(
              scale: on ? 1 : 0.8,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: Tooltip(
                message: label,
                excludeFromSemantics: true,
                child: Semantics(
                  button: onTap != null,
                  label: label,
                  child: MouseRegion(
                    cursor: onTap == null
                        ? MouseCursor.defer
                        : SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        decoration: BoxDecoration(
                          color: c.field,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedOpacity(
                              opacity: partial ? 0.5 : 1,
                              duration: duration,
                              child: MgIcon(
                                MgIcons.ghost,
                                size: 13,
                                color: c.fg2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
