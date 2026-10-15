import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';

const _correct = Color(0xFF34C759);
const _wrong = Color(0xFFFF3B30);

/// A poll or quiz in the timeline, as Telegram for macOS shows it: the
/// question, what kind of poll it is, and the options. Before the user
/// votes, each option has a radio or a checkbox; a poll with several
/// answers collects them and votes on the Vote button. Once voted, or
/// when the results are open, each option shows its share with a bar,
/// the user's choice marked, a quiz's right and wrong answers coloured.
/// The footer counts the votes and offers to take the vote back.
class PollContent extends StatefulWidget {
  const PollContent({
    super.key,
    required this.poll,
    required this.description,
    this.onVote,
  });

  final td.Poll poll;
  final td.FormattedText description;

  /// Votes for the options with these ids; an empty list takes the vote
  /// back. Null when the poll can't be voted in from here.
  final void Function(List<int> optionIds)? onVote;

  @override
  State<PollContent> createState() => _PollContentState();
}

class _PollContentState extends State<PollContent> {
  /// The options ticked but not yet sent, in a poll with several answers.
  final _picked = <int>{};

  td.Poll get poll => widget.poll;

  bool get _voted => poll.options.any((o) => o.isChosen || o.isBeingChosen);

  bool get _showResults => poll.isClosed || _voted || poll.canSeeResults;

  bool get _canVote =>
      widget.onVote != null && !poll.isClosed && !_voted && !_showResults;

  td.PollTypeQuiz? get _quiz => switch (poll.type) {
    final td.PollTypeQuiz quiz => quiz,
    _ => null,
  };

  @override
  void didUpdateWidget(PollContent old) {
    super.didUpdateWidget(old);
    if (old.poll.id != poll.id || _voted) _picked.clear();
  }

  void _tap(int index) {
    if (!_canVote) return;
    if (!poll.allowsMultipleAnswers) {
      widget.onVote!([index]);
      return;
    }
    setState(() {
      if (!_picked.remove(index)) _picked.add(index);
    });
  }

  void _vote() {
    if (_picked.isEmpty) return;
    widget.onVote!(_picked.toList()..sort());
  }

  String _kind(AppLocalizations l10n) {
    if (poll.isClosed) return l10n.pollFinalResults;
    final quiz = _quiz != null;
    if (poll.isAnonymous) {
      return quiz ? l10n.pollAnonymousQuiz : l10n.pollAnonymous;
    }
    return quiz ? l10n.contentQuiz : l10n.contentPoll;
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final quiz = _quiz;
    final showResults = _showResults;
    final canRetract =
        widget.onVote != null &&
        _voted &&
        poll.allowsRevoting &&
        !poll.isClosed &&
        quiz == null;
    final explanation = quiz?.explanation.text ?? '';
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            poll.question.text,
            style: mgTextStyle(c, weight: FontWeight.w600),
          ),
          if (widget.description.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(widget.description.text, style: mgTextStyle(c)),
            ),
          const SizedBox(height: 2),
          Text(_kind(l10n), style: MessageMeta.styleOf(c)),
          const SizedBox(height: 8),
          for (final (index, option) in poll.options.indexed)
            _Option(
              option: option,
              index: index,
              showResults: showResults,
              picked: _picked.contains(index),
              multiple: poll.allowsMultipleAnswers,
              correct: quiz?.correctOptionIds.contains(index),
              onTap: _canVote ? () => _tap(index) : null,
            ),
          if (_canVote && poll.allowsMultipleAnswers)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Center(
                child: _TextButton(
                  label: l10n.pollVote,
                  enabled: _picked.isNotEmpty,
                  onTap: _vote,
                ),
              ),
            )
          else if (canRetract)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Center(
                child: _TextButton(
                  label: l10n.pollRetractVote,
                  onTap: () => widget.onVote!(const []),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                quiz != null
                    ? l10n.quizAnswers(poll.totalVoterCount)
                    : l10n.pollVotes(poll.totalVoterCount),
                style: MessageMeta.styleOf(c),
              ),
            ),
          if (quiz != null && _voted && explanation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                explanation,
                style: mgTextStyle(c, color: c.fg2, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.option,
    required this.index,
    required this.showResults,
    required this.picked,
    required this.multiple,
    required this.correct,
    required this.onTap,
  });

  final td.PollOption option;
  final int index;
  final bool showResults;
  final bool picked;
  final bool multiple;

  /// In a quiz: whether this option is a right answer. Null in a poll.
  final bool? correct;
  final VoidCallback? onTap;

  static const _duration = Duration(milliseconds: 260);
  static const _curve = Cubic(0.23, 1, 0.32, 1);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final chosen = option.isChosen || option.isBeingChosen;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final duration = animate ? _duration : Duration.zero;
    // The results colour a quiz's answers: the right one green, a wrong
    // choice red. Everything else keeps the accent.
    final tint = switch (correct) {
      true when showResults => _correct,
      false when showResults && chosen => _wrong,
      _ => c.accent,
    };
    final marker = showResults
        ? _ResultMark(
            visible: chosen || (correct ?? false),
            tint: tint,
            wrong: correct == false && chosen,
          )
        : _Choice(picked: picked, multiple: multiple, accent: c.accent);
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 38,
                child: showResults
                    ? Text(
                        '${option.votePercentage}%',
                        style: mgTextStyle(c, weight: FontWeight.w600),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 1),
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: _curve,
                  child: KeyedSubtree(
                    key: ValueKey(showResults),
                    child: marker,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  option.text.text,
                  style: mgTextStyle(
                    c,
                    weight: chosen ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 38, top: 5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: LayoutBuilder(
                  builder: (context, box) => Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: duration,
                      curve: _curve,
                      width: showResults
                          ? box.maxWidth * option.votePercentage / 100
                          : 0,
                      color: tint,
                    ),
                  ),
                ),
              ),
            ),
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

/// The radio or checkbox of an option before voting.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.picked,
    required this.multiple,
    required this.accent,
  });

  final bool picked;
  final bool multiple;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: picked ? accent : const Color(0x00000000),
        shape: multiple ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multiple ? BorderRadius.circular(5) : null,
        border: Border.all(
          color: picked ? accent : c.fg2.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: picked
          ? MgIcon(MgIcons.check, size: 12, color: c.onAccent, stroke: 2.4)
          : null,
    );
  }
}

/// The mark next to an option in the results: a tick on the user's
/// choice and on a quiz's right answer, a cross on a wrong choice,
/// nothing elsewhere.
class _ResultMark extends StatelessWidget {
  const _ResultMark({
    required this.visible,
    required this.tint,
    required this.wrong,
  });

  final bool visible;
  final Color tint;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return SizedBox(
      width: 18,
      height: 18,
      child: visible
          ? DecoratedBox(
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: MgIcon(
                wrong ? MgIcons.close : MgIcons.check,
                size: 11,
                color: c.onAccent,
                stroke: 2.4,
              ),
            )
          : null,
    );
  }
}

/// Vote and Retract vote: accent text, dimmed while nothing is picked.
class _TextButton extends StatelessWidget {
  const _TextButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: enabled ? 1 : 0.45,
            child: Text(
              label,
              style: mgTextStyle(c, weight: FontWeight.w600, color: c.accent),
            ),
          ),
        ),
      ),
    );
  }
}
