import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'formatted_text.dart';

/// A checklist in the timeline, as Telegram for macOS shows it: the title,
/// then each task with a rounded box that fills with the accent and a tick
/// once done, the task's text struck through and the avatar of whoever
/// did it at the right; a footer counts the tasks done. A click on a task
/// marks it done or not done when the list allows it.
class ChecklistContent extends StatelessWidget {
  const ChecklistContent({
    super.key,
    required this.list,
    this.onToggle,
    this.completerAvatar,
  });

  final td.Checklist list;

  /// Marks task [taskId] done or not done. Null when the user may not,
  /// which draws the list read-only.
  final void Function(int taskId, bool done)? onToggle;

  /// The avatar of whoever completed a task, [size] wide.
  final Widget Function(td.MessageSender sender, double size)? completerAvatar;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final onToggle = list.canMarkTasksAsDone ? this.onToggle : null;
    final done = list.tasks.where((t) => t.completedBy != null).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormattedTextView(
          text: list.title,
          style: mgTextStyle(c, weight: FontWeight.w600),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 10),
          child: Text(
            l10n.contentChecklist,
            style: mgTextStyle(c, size: MgType.small, color: c.fg2),
          ),
        ),
        for (final task in list.tasks)
          _Task(
            task: task,
            avatar: completerAvatar,
            onTap: onToggle == null
                ? null
                : () => onToggle(task.id, task.completedBy == null),
          ),
        Text(
          l10n.checklistProgress(done, list.tasks.length),
          style: mgTextStyle(c, size: MgType.small, color: c.fg2),
        ),
      ],
    );
  }
}

class _Task extends StatelessWidget {
  const _Task({required this.task, required this.avatar, required this.onTap});

  final td.ChecklistTask task;
  final Widget Function(td.MessageSender sender, double size)? avatar;
  final VoidCallback? onTap;

  static const _duration = Duration(milliseconds: 160);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final completedBy = task.completedBy;
    final done = completedBy != null;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final duration = animate ? _duration : Duration.zero;
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 10),
            child: AnimatedContainer(
              duration: duration,
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: done ? c.accent : const Color(0x00000000),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: done ? c.accent : c.fg2.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              child: done
                  ? MgIcon(
                      MgIcons.check,
                      size: 12,
                      color: c.onAccent,
                      stroke: 2.4,
                    )
                  : null,
            ),
          ),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: duration,
              style: mgTextStyle(c, color: done ? c.fg2 : c.fg).copyWith(
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: c.fg2,
              ),
              child: FormattedTextView(text: task.text),
            ),
          ),
          if (done && avatar != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 1),
              child: avatar!(completedBy, 16),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}
