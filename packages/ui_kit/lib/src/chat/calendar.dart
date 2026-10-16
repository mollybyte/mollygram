import 'package:flutter/widgets.dart';

import '../glass/glass.dart';
import '../icon_button.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// A month of days to jump to, as in Telegram for macOS: the month and
/// year with arrows above a grid of weeks. Days after [today] can't be
/// picked, nor days before [first] when it is given. The kit has no
/// strings: the app formats the month title and the weekday letters.
class MgCalendar extends StatefulWidget {
  const MgCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.onPick,
    required this.monthTitle,
    required this.weekdays,
    required this.previousTooltip,
    required this.nextTooltip,
    this.first,
    this.firstWeekday = DateTime.monday,
  });

  /// Any day of the month shown first.
  final DateTime month;
  final DateTime today;
  final DateTime? first;
  final void Function(DateTime day) onPick;

  /// "October 2026".
  final String Function(DateTime month) monthTitle;

  /// Seven labels from Monday, such as "M", "T", "W".
  final List<String> weekdays;
  final String previousTooltip;
  final String nextTooltip;

  /// [DateTime.monday] or [DateTime.sunday].
  final int firstWeekday;

  static const double cell = 32;
  static const double width = cell * 7 + MgSpace.l * 2;

  @override
  State<MgCalendar> createState() => _MgCalendarState();
}

class _MgCalendarState extends State<MgCalendar> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);

  DateTime get _today =>
      DateTime(widget.today.year, widget.today.month, widget.today.day);

  DateTime? get _first {
    final first = widget.first;
    return first == null ? null : DateTime(first.year, first.month, first.day);
  }

  bool get _hasPrevious {
    final first = _first;
    return first == null || DateTime(first.year, first.month).isBefore(_month);
  }

  bool get _hasNext => DateTime(_today.year, _today.month).isAfter(_month);

  void _move(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  bool _enabled(DateTime day) {
    if (day.isAfter(_today)) return false;
    final first = _first;
    return first == null || !day.isBefore(first);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Blank cells before the first of the month.
    final lead = (_month.weekday - widget.firstWeekday + 7) % 7;
    final weeks = ((lead + daysInMonth) / 7).ceil();
    return Glass(
      radius: MgRadius.popover,
      padding: const EdgeInsets.fromLTRB(
        MgSpace.l,
        MgSpace.m,
        MgSpace.l,
        MgSpace.l,
      ),
      child: SizedBox(
        width: MgCalendar.width - MgSpace.l * 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                MgIconButton(
                  icon: MgIcons.back,
                  tooltip: widget.previousTooltip,
                  iconSize: 15,
                  onPressed: _hasPrevious ? () => _move(-1) : null,
                ),
                Expanded(
                  child: Text(
                    widget.monthTitle(_month),
                    textAlign: TextAlign.center,
                    style: mgTextStyle(c, weight: FontWeight.w600),
                  ),
                ),
                MgIconButton(
                  icon: MgIcons.chevron,
                  tooltip: widget.nextTooltip,
                  iconSize: 15,
                  onPressed: _hasNext ? () => _move(1) : null,
                ),
              ],
            ),
            const SizedBox(height: MgSpace.s),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  SizedBox(
                    width: MgCalendar.cell,
                    child: Text(
                      widget.weekdays[(widget.firstWeekday - 1 + i) % 7],
                      textAlign: TextAlign.center,
                      style: mgTextStyle(
                        c,
                        size: MgType.caption,
                        weight: FontWeight.w500,
                        color: c.fg2,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: MgSpace.xs),
            for (var week = 0; week < weeks; week++)
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    () {
                      final number = week * 7 + i - lead + 1;
                      if (number < 1 || number > daysInMonth) {
                        return const SizedBox.square(
                          dimension: MgCalendar.cell,
                        );
                      }
                      final day = DateTime(_month.year, _month.month, number);
                      return _Day(
                        label: '$number',
                        today: day == _today,
                        onTap: _enabled(day) ? () => widget.onPick(day) : null,
                      );
                    }(),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Day extends StatefulWidget {
  const _Day({required this.label, required this.today, required this.onTap});

  final String label;
  final bool today;
  final VoidCallback? onTap;

  @override
  State<_Day> createState() => _DayState();
}

class _DayState extends State<_Day> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = widget.onTap != null;
    final lit = _hover && enabled;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox.square(
          dimension: MgCalendar.cell,
          child: Center(
            child: AnimatedContainer(
              duration: MgMotion.fast,
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lit ? c.accent : const Color(0x00000000),
                border: widget.today && !lit
                    ? Border.all(color: c.accent, width: 1.5)
                    : null,
              ),
              child: Text(
                widget.label,
                style: mgTextStyle(
                  c,
                  weight: widget.today ? FontWeight.w600 : FontWeight.w400,
                  color: lit
                      ? c.onAccent
                      : !enabled
                      ? c.fg2.withValues(alpha: 0.4)
                      : widget.today
                      ? c.accent
                      : c.fg,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
