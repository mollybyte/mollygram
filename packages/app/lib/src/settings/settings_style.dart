import 'package:flutter/material.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// The solid surfaces of the settings window, after macOS System Settings:
/// a tinted source list, a recessed content pane and solid boxes on it.
@immutable
class SettingsColors {
  const SettingsColors._({
    required this.sidebar,
    required this.pane,
    required this.group,
    required this.groupBorder,
    required this.pressed,
  });

  final Color sidebar;
  final Color pane;
  final Color group;

  /// The hairline of a box that lies on another surface; groups on the
  /// pane only draw it in dark.
  final Color groupBorder;

  /// A row while the mouse is down on it.
  final Color pressed;

  /// The window's own surfaces, as in the chats: the source list lies on
  /// the frame, and the pane, between the frame and the card, carries
  /// groups in the card's colour (white on grey, as TelegramSwift draws
  /// its blocks). Each wallpaper tint sets frame and card as a pair, so
  /// the mix follows it.
  static SettingsColors of(BuildContext context) {
    final c = MgColors.of(context);
    return SettingsColors._(
      sidebar: c.solid(c.frame),
      pane: c.solid(Color.lerp(c.card, c.frame, 0.65)!),
      group: c.solid(c.card),
      groupBorder: c.separator,
      pressed: c.isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000),
    );
  }
}

/// The horizontal inset of a row's content, its section header and its
/// footer: TelegramSwift's 14, which MgSpace has no step for.
const settingsInset = 14.0;

/// How long a settings transition takes: short and eased, so it reads as
/// a response to the click rather than an animation to wait for.
const settingsMotion = Duration(milliseconds: 180);
const settingsCurve = Curves.easeOutCubic;

/// The small rounded-square symbol of a section, as in System Settings: a
/// white glyph on a tinted tile with a soft top-to-bottom shade.
class SettingsSymbol extends StatelessWidget {
  const SettingsSymbol({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 24,
  });

  final MgIconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      // 7 on the 24 tile, TelegramSwift's continuous corner.
      borderRadius: BorderRadius.circular(size * 7 / 24),
      // The faint rim keeps the tile apart from a selection of the same hue.
      border: Border.all(color: const Color(0x2EFFFFFF), width: 0.5),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(tint, Colors.white, 0.14)!, tint],
      ),
    ),
    child: MgIcon(
      icon,
      size: size * 0.64,
      stroke: 2.1,
      color: const Color(0xFFFFFFFF),
    ),
  );
}

/// A page of the content pane: grouped boxes in a centered column.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(MgSpace.xxl, 4, MgSpace.xxl, 28),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

/// A rounded box of rows with hairlines between them, with an optional
/// [title] above and a [footer] below.
/// A widget that builds a [SettingsRow] or [SettingsSwitchRow], so a
/// [SettingsGroup] lets the row draw its own hairline from the title on
/// instead of a full-width one at the row inset.
abstract interface class SettingsGroupRow implements Widget {}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    this.title,
    this.footer,
  });

  final List<Widget> children;
  final String? title;

  /// Usually a [SettingsFooter].
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = SettingsColors.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final last = i == children.length - 1;
      // A row draws its own hairline, from its title on (see SettingsRow);
      // anything else gets one at the row inset.
      if (child is SettingsGroupRow) {
        rows.add(_RowSeparator(below: !last, child: child));
      } else {
        rows.add(child);
        if (!last) {
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: settingsInset),
              child: Container(height: 0.5, color: c.separator),
            ),
          );
        }
      }
    }
    final shape = BorderRadius.circular(MgRadius.popover);
    return Padding(
      padding: const EdgeInsets.only(top: MgSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                settingsInset,
                0,
                settingsInset,
                MgSpace.s,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: mgTextStyle(
                    c,
                    size: MgType.small,
                    weight: MgWeight.medium,
                    color: c.fg2,
                  ),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: s.group,
              borderRadius: shape,
              // The card is lighter than the pane in light; in dark the
              // two are close, and a hairline keeps the box apart.
              border: c.isDark
                  ? Border.all(color: s.groupBorder, width: 0.5)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: shape,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
          ?footer,
        ],
      ),
    );
  }
}

/// Tells a [SettingsRow] in a [SettingsGroup] whether a hairline goes
/// under it.
class _RowSeparator extends InheritedWidget {
  const _RowSeparator({required this.below, required super.child});

  final bool below;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowSeparator>()?.below ??
      false;

  @override
  bool updateShouldNotify(_RowSeparator old) => old.below != below;
}

/// The small text under a group. [error] paints it red, [success] in the
/// accent.
class SettingsFooter extends StatelessWidget {
  const SettingsFooter(
    this.text, {
    super.key,
    this.error = false,
    this.success = false,
  });

  final String text;
  final bool error;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        settingsInset,
        MgSpace.s,
        settingsInset,
        0,
      ),
      child: AnimatedSwitcher(
        duration: settingsMotionOf(context),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, ?current],
        ),
        child: Text(
          text,
          key: ValueKey((text, error, success)),
          style: mgTextStyle(
            c,
            size: MgType.caption,
            color: error
                ? MgDestructive.color
                : success
                ? c.accent
                : c.fg2,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

/// One line of a group: an optional [leading] symbol or avatar, the
/// [title] with an optional [subtitle], and a [trailing] value or control.
/// With [onTap] the row highlights while pressed and shows a chevron when
/// [chevron] is set.
class SettingsRow extends StatefulWidget implements SettingsGroupRow {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool destructive;

  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  final _leading = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = SettingsColors.of(context);
    final tappable = widget.onTap != null;
    final subtitle = widget.subtitle;
    final separator = _RowSeparator.of(context);
    Widget body({bool hover = false, bool pressed = false}) {
      Widget row = AnimatedContainer(
        duration: pressed ? MgMotion.press : const Duration(milliseconds: 90),
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(
          horizontal: settingsInset,
          vertical: 7,
        ),
        color: pressed
            ? s.pressed
            : hover
            ? c.hover
            : s.group.withValues(alpha: 0),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              KeyedSubtree(key: _leading, child: widget.leading!),
              const SizedBox(width: _leadingGap),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(
                      c,
                      color: widget.destructive ? MgDestructive.color : null,
                      height: 1.3,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(
                        c,
                        size: MgType.small,
                        color: c.fg2,
                        height: 1.35,
                      ),
                    ),
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 10),
              widget.trailing!,
            ],
            if (widget.chevron) ...[
              const SizedBox(width: 6),
              MgIcon(MgIcons.chevron, size: 12, stroke: 1.8, color: c.muted),
            ],
          ],
        ),
      );
      if (separator) {
        row = CustomPaint(
          foregroundPainter: _SeparatorPainter(
            color: c.separator,
            leading: widget.leading == null ? null : _leading,
          ),
          child: row,
        );
      }
      return row;
    }

    if (!tappable) return MergeSemantics(child: body());
    return MergeSemantics(
      child: MgPressable(
        scale: 1,
        focusRadius: 0,
        onTap: widget.onTap,
        builder: (context, state) =>
            body(hover: state.hovered, pressed: state.pressed),
      ),
    );
  }
}

/// The gap between a row's leading item and its title.
const _leadingGap = 10.0;

/// The hairline under a row: from the title's x, past the leading item as
/// TelegramSwift indents it, to the row inset on the right.
class _SeparatorPainter extends CustomPainter {
  const _SeparatorPainter({required this.color, required this.leading});

  final Color color;

  /// The leading item, measured once laid out; its width moves the start.
  final GlobalKey? leading;

  @override
  void paint(Canvas canvas, Size size) {
    final box = leading?.currentContext?.findRenderObject() as RenderBox?;
    final start =
        settingsInset +
        (box != null && box.hasSize ? box.size.width + _leadingGap : 0);
    canvas.drawRect(
      Rect.fromLTRB(
        start,
        size.height - 0.5,
        size.width - settingsInset,
        size.height,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SeparatorPainter old) =>
      old.color != color || old.leading != leading;
}

/// A small macOS push button, such as "Log out…" under a group.
class SettingsButton extends StatelessWidget {
  const SettingsButton({
    super.key,
    required this.label,
    this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = SettingsColors.of(context);
    final enabled = onPressed != null;
    return MgPressable(
      onTap: onPressed,
      semanticsLabel: label,
      focusRadius: 6,
      builder: (context, state) => AnimatedOpacity(
        duration: settingsMotionOf(context),
        opacity: enabled ? 1 : 0.45,
        child: AnimatedContainer(
          duration: state.pressed ? MgMotion.press : MgMotion.fast,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: state.pressed
                ? s.pressed
                : state.hovered
                ? Color.alphaBlend(c.hover, c.field)
                : c.field,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: s.groupBorder, width: 0.5),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              style: mgTextStyle(
                c,
                color: destructive ? MgDestructive.color : null,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small spinner for a row or a page that is loading.
class SettingsSpinner extends StatelessWidget {
  const SettingsSpinner({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      strokeWidth: 1.6,
      color: MgColors.of(context).fg2,
    ),
  );
}

/// [settingsMotion], or nothing when animations are off (the system's or
/// Mollygram's "Reduce motion").
Duration settingsMotionOf(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : settingsMotion;

/// A macOS switch: a small capsule, the accent when on.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Read by screen readers when the row doesn't say it.
  final String? label;

  static const _width = 32.0;
  static const _height = 18.0;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = onChanged != null;
    final motion = settingsMotionOf(context);
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: label,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: enabled ? () => onChanged!(!value) : null,
          child: AnimatedOpacity(
            duration: motion,
            opacity: enabled ? 1 : 0.45,
            child: AnimatedContainer(
              duration: motion,
              curve: settingsCurve,
              width: _width,
              height: _height,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value
                    ? c.accent
                    : (c.isDark
                          ? const Color(0xFF48484C)
                          : const Color(0xFFD9D9DE)),
                borderRadius: BorderRadius.circular(_height / 2),
              ),
              child: AnimatedAlign(
                duration: motion,
                curve: settingsCurve,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: _height - 4,
                  height: _height - 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
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

/// A group row with a switch; a click anywhere on the row flips it.
class SettingsSwitchRow extends StatelessWidget implements SettingsGroupRow {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SettingsRow(
    title: title,
    subtitle: subtitle,
    leading: leading,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    trailing: ExcludeSemantics(
      child: SettingsSwitch(value: value, onChanged: onChanged),
    ),
  );
}
