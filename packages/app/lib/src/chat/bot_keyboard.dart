import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

const _danger = Color(0xFFFF3B30);
const _success = Color(0xFF34C759);

/// A bot's buttons under its message: rows of pills the width of the
/// message, as Telegram for macOS lays them out. [onPressed] gets the
/// button; what it does depends on its type.
class InlineKeyboard extends StatelessWidget {
  const InlineKeyboard({
    super.key,
    required this.rows,
    required this.onPressed,
  });

  final List<List<td.InlineKeyboardButton>> rows;
  final void Function(td.InlineKeyboardButton button)? onPressed;

  @override
  Widget build(BuildContext context) => _Rows(
    rows: [
      for (final row in rows)
        [
          for (final button in row)
            _Key(
              label: button.text,
              style: button.style,
              trailing: switch (button.type) {
                td.InlineKeyboardButtonTypeUrl() ||
                td.InlineKeyboardButtonTypeLoginUrl() ||
                td.InlineKeyboardButtonTypeWebApp() => '↗',
                td.InlineKeyboardButtonTypeSwitchInline() => '⇄',
                _ => null,
              },
              enabled:
                  onPressed != null &&
                  button.type is! td.InlineKeyboardButtonTypeDisabled,
              onPressed: () => onPressed?.call(button),
            ),
        ],
    ],
  );
}

/// A bot's keyboard in place of the usual one, above the composer: rows
/// of text buttons, each sending its text. Buttons that ask for a phone,
/// a location or a poll can't be pressed yet.
class ReplyKeyboard extends StatelessWidget {
  const ReplyKeyboard({super.key, required this.rows, required this.onPressed});

  final List<List<td.KeyboardButton>> rows;
  final void Function(String text) onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
    child: _Rows(
      rows: [
        for (final row in rows)
          [
            for (final button in row)
              _Key(
                label: button.text,
                style: button.style,
                enabled: button.type is td.KeyboardButtonTypeText,
                onPressed: () => onPressed(button.text),
              ),
          ],
      ],
    ),
  );
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<List<_Key>> rows;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, row) in rows.indexed)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
          child: Row(
            children: [
              for (final (j, key) in row.indexed)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: j == 0 ? 0 : 4),
                    child: key,
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

/// One button: a solid pill that brightens under the pointer and sinks a
/// little when pressed. Coloured by the bot's style, the accent for a
/// primary one.
class _Key extends StatefulWidget {
  const _Key({
    required this.label,
    required this.style,
    required this.enabled,
    required this.onPressed,
    this.trailing,
  });

  final String label;
  final td.ButtonStyle style;
  final bool enabled;
  final VoidCallback onPressed;
  final String? trailing;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  var _hover = false;
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final (Color background, Color foreground) = switch (widget.style) {
      td.ButtonStylePrimary() => (c.accent, c.onAccent),
      td.ButtonStyleDanger() => (_danger, const Color(0xFFFFFFFF)),
      td.ButtonStyleSuccess() => (_success, const Color(0xFFFFFFFF)),
      td.ButtonStyleLink() => (const Color(0x00000000), c.accent),
      _ => (c.datePill, c.fg),
    };
    final animate = !MediaQuery.disableAnimationsOf(context);
    final pill = AnimatedContainer(
      duration: Duration(milliseconds: animate ? 120 : 0),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      transformAlignment: Alignment.center,
      transform: Matrix4.diagonal3Values(_down ? 0.97 : 1, _down ? 0.97 : 1, 1),
      decoration: BoxDecoration(
        color: _hover && widget.enabled
            ? Color.lerp(background, c.fg, 0.08)
            : background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: mgTextStyle(
                c,
                weight: FontWeight.w500,
                color: widget.enabled
                    ? foreground
                    : foreground.withValues(alpha: 0.5),
              ),
            ),
          ),
          if (widget.trailing case final trailing?)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                trailing,
                style: mgTextStyle(
                  c,
                  size: MgType.small,
                  color: foreground.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
    if (!widget.enabled) return pill;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = _down = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: pill,
      ),
    );
  }
}
