import 'package:flutter/material.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// The solid surfaces of the settings window, after macOS System Settings:
/// a tinted source list, a plain content pane and grouped boxes on it.
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
  final Color groupBorder;

  /// A row while the mouse is down on it.
  final Color pressed;

  static const _light = SettingsColors._(
    sidebar: Color(0xFFF0F0F2),
    pane: Color(0xFFFFFFFF),
    group: Color(0xFFF6F6F8),
    groupBorder: Color(0x0F000000),
    pressed: Color(0x14000000),
  );

  static const _dark = SettingsColors._(
    sidebar: Color(0xFF242427),
    pane: Color(0xFF1C1C1E),
    group: Color(0xFF262628),
    groupBorder: Color(0x14FFFFFF),
    pressed: Color(0x1AFFFFFF),
  );

  static SettingsColors of(BuildContext context) =>
      MgColors.of(context).isDark ? _dark : _light;
}

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
    this.size = 22,
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
      borderRadius: BorderRadius.circular(size * 0.27),
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
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

/// A rounded inset box of rows with hairlines between them, with an
/// optional bold [title] above and a [footer] below.
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
      if (i > 0) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(height: 0.5, color: c.separator),
          ),
        );
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 7),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: mgTextStyle(c, weight: FontWeight.w600),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: s.group,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.groupBorder, width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
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
class SettingsRow extends StatefulWidget {
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
  var _pressed = false;
  var _hover = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = SettingsColors.of(context);
    final tappable = widget.onTap != null;
    final subtitle = widget.subtitle;
    Widget row = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: _pressed
          ? s.pressed
          : _hover && tappable
          ? c.hover
          : s.group.withValues(alpha: 0),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 10),
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
                      size: MgType.caption,
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
            MgIcon(MgIcons.chevron, size: 13, stroke: 2.2, color: c.fg2),
          ],
        ],
      ),
    );
    if (!tappable) return MergeSemantics(child: row);
    row = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapCancel: () => _press(false),
        onTapUp: (_) => _press(false),
        onTap: widget.onTap,
        child: row,
      ),
    );
    return MergeSemantics(
      child: Semantics(button: true, onTap: widget.onTap, child: row),
    );
  }
}

/// A small macOS push button, such as "Log out…" under a group.
class SettingsButton extends StatefulWidget {
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
  State<SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<SettingsButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = SettingsColors.of(context);
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedOpacity(
            duration: settingsMotionOf(context),
            opacity: enabled ? 1 : 0.45,
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: _pressed ? s.pressed : c.field,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: s.groupBorder, width: 0.5),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  style: mgTextStyle(
                    c,
                    color: widget.destructive ? MgDestructive.color : null,
                    height: 1.2,
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
class SettingsSwitchRow extends StatelessWidget {
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
