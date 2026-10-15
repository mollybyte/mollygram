import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';

/// Asks when a message should go out: a calendar for the day and a field
/// for the time, as Telegram for macOS does. Completes with the moment,
/// or null when cancelled. Starts an hour ahead, on the hour.
Future<DateTime?> pickScheduleTime(BuildContext context) =>
    showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0x00000000),
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => const Center(
        child: Material(type: MaterialType.transparency, child: _Picker()),
      ),
    );

class _Picker extends StatefulWidget {
  const _Picker();

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late final DateTime _now = DateTime.now();
  late DateTime _day = DateTime(_now.year, _now.month, _now.day);
  late final _time = TextEditingController(
    text: DateFormat.Hm().format(_now.add(const Duration(hours: 1))),
  );

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  /// The chosen moment when the time reads as hours and minutes and lies
  /// ahead; null otherwise.
  DateTime? get _when {
    final match = RegExp(r'^(\d{1,2})[:.](\d{2})$')
        .firstMatch(_time.text.trim());
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return null;
    final when = DateTime(_day.year, _day.month, _day.day, hour, minute);
    return when.isAfter(DateTime.now()) ? when : null;
  }

  void _confirm() {
    final when = _when;
    if (when != null) Navigator.of(context).pop(when);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekdayFormat = DateFormat.E(locale);
    final style = mgTextStyle(c);
    final ready = _when != null;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: SizedBox(
        width: MgCalendar.width + 36,
        child: Glass(
          radius: 14,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.scheduleTitle,
                style: mgTextStyle(c, weight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(l10n.scheduleHint, style: mgTextStyle(c, color: c.fg2)),
              const SizedBox(height: 10),
              Center(
                child: MgCalendar(
                  month: _day,
                  today: _now,
                  first: DateTime(_now.year, _now.month, _now.day),
                  monthTitle: (month) => DateFormat.yMMMM(locale).format(month),
                  weekdays: [
                    for (var i = 0; i < 7; i++)
                      // 2024-01-01 is a Monday.
                      weekdayFormat
                          .format(DateTime(2024, 1, 1 + i))
                          .characters
                          .first,
                  ],
                  previousTooltip: l10n.previousMonth,
                  nextTooltip: l10n.nextMonth,
                  onPick: (day) => setState(() => _day = day),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat.yMMMMEEEEd(locale).format(_day),
                      style: style,
                    ),
                  ),
                  Container(
                    width: 72,
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.field,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: TextField(
                      controller: _time,
                      autofocus: true,
                      style: style,
                      cursorHeight: 15,
                      textAlign: TextAlign.center,
                      maxLength: 5,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _confirm(),
                      decoration: InputDecoration.collapsed(
                        hintText: l10n.scheduleTimeHint,
                        hintStyle: style.copyWith(color: c.fg2),
                      ).copyWith(counterText: ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MgDialogButton(
                    label: l10n.cancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: ready ? 1 : 0.5,
                    child: MgDialogButton(
                      label: l10n.scheduleAction,
                      filled: true,
                      onTap: _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
