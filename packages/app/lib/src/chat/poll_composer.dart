import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';

/// Asks for a new poll, as Telegram for macOS does: the question, up to
/// ten options, and the switches for anonymous voting, several answers
/// and quiz mode with its right answer and explanation. Completes with
/// the poll to send, or null when cancelled. [inChannel] hides the
/// anonymity switch, since channel polls are always anonymous. [quiz]
/// fixes the mode, as a bot's request for a poll may, and hides its
/// switch.
Future<td.InputMessagePoll?> composePoll(
  BuildContext context, {
  bool inChannel = false,
  bool? quiz,
}) => showGeneralDialog<td.InputMessagePoll>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: const Color(0x00000000),
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) => Center(
    child: Material(
      type: MaterialType.transparency,
      child: _PollComposer(inChannel: inChannel, quiz: quiz),
    ),
  ),
);

class _PollComposer extends StatefulWidget {
  const _PollComposer({required this.inChannel, required this.quiz});

  final bool inChannel;
  final bool? quiz;

  @override
  State<_PollComposer> createState() => _PollComposerState();
}

class _PollComposerState extends State<_PollComposer> {
  static const maxOptions = 10;

  final _question = TextEditingController();
  final _explanation = TextEditingController();
  final _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  var _anonymous = true;
  var _multiple = false;
  late var _quiz = widget.quiz ?? false;
  int? _correct;

  @override
  void initState() {
    super.initState();
    _question.addListener(_changed);
    for (final option in _options) {
      option.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _question.dispose();
    _explanation.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  /// A filled last option makes room for one more; the list never shows
  /// more than one empty option at its end.
  void _changed() {
    final filled = [for (final o in _options) o.text.trim().isNotEmpty];
    if (filled.last && _options.length < maxOptions) {
      _options.add(TextEditingController()..addListener(_changed));
    }
    setState(() {});
  }

  void _remove(int index) {
    if (_options.length <= 2) return;
    final removed = _options.removeAt(index);
    removed.dispose();
    if (_correct == index) {
      _correct = null;
    } else if (_correct != null && _correct! > index) {
      _correct = _correct! - 1;
    }
    setState(() {});
  }

  List<String> get _answers => [
    for (final o in _options)
      if (o.text.trim().isNotEmpty) o.text.trim(),
  ];

  bool get _ready {
    if (_question.text.trim().isEmpty || _answers.length < 2) return false;
    if (_quiz) {
      final correct = _correct;
      return correct != null &&
          correct < _options.length &&
          _options[correct].text.trim().isNotEmpty;
    }
    return true;
  }

  void _create() {
    if (!_ready) return;
    // The right answer's index among the filled options only.
    var correct = 0;
    if (_quiz) {
      for (var i = 0; i < _correct!; i++) {
        if (_options[i].text.trim().isNotEmpty) correct++;
      }
    }
    Navigator.of(context).pop(
      td.InputMessagePoll(
        question: td.FormattedText(
          text: _question.text.trim(),
          entities: const [],
        ),
        options: [
          for (final answer in _answers)
            td.InputPollOption(
              text: td.FormattedText(text: answer, entities: const []),
            ),
        ],
        isAnonymous: widget.inChannel || _anonymous,
        allowsMultipleAnswers: !_quiz && _multiple,
        allowsRevoting: !_quiz,
        membersOnly: false,
        countryCodes: const [],
        shuffleOptions: false,
        hideResultsUntilCloses: false,
        type: _quiz
            ? td.InputPollTypeQuiz(
                correctOptionIds: [correct],
                explanation: td.FormattedText(
                  text: _explanation.text.trim(),
                  entities: const [],
                ),
              )
            : const td.InputPollTypeRegular(allowAddingOptions: false),
        openPeriod: 0,
        closeDate: 0,
        isClosed: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final ready = _ready;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: SizedBox(
        width: 420,
        child: Glass(
          radius: 14,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _quiz ? l10n.newQuizTitle : l10n.newPollTitle,
                style: mgTextStyle(c, weight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              MgUnderlineField(
                controller: _question,
                hintText: l10n.pollQuestionHint,
                autofocus: true,
                fontSize: 14,
              ),
              const SizedBox(height: 14),
              Text(l10n.pollOptionsTitle, style: mgTextStyle(c, color: c.fg2)),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final (i, option) in _options.indexed)
                      _OptionRow(
                        key: ObjectKey(option),
                        controller: option,
                        hint: l10n.pollOptionHint,
                        quiz: _quiz,
                        correct: _correct == i,
                        onCorrect: () => setState(() => _correct = i),
                        onRemove:
                            _options.length > 2 && option.text.trim().isNotEmpty
                            ? () => _remove(i)
                            : null,
                        removeTooltip: l10n.pollRemoveOption,
                        correctTooltip: l10n.pollCorrectAnswer,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!widget.inChannel)
                _SwitchRow(
                  label: l10n.pollAnonymousVoting,
                  value: _anonymous,
                  onChanged: (v) => setState(() => _anonymous = v),
                ),
              _SwitchRow(
                label: l10n.pollMultipleAnswers,
                value: !_quiz && _multiple,
                enabled: !_quiz,
                onChanged: (v) => setState(() => _multiple = v),
              ),
              if (widget.quiz == null)
                _SwitchRow(
                  label: l10n.pollQuizMode,
                  value: _quiz,
                  onChanged: (v) => setState(() => _quiz = v),
                ),
              if (_quiz) ...[
                const SizedBox(height: 6),
                MgUnderlineField(
                  controller: _explanation,
                  hintText: l10n.pollExplanationHint,
                  fontSize: 13,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.pollQuizHint,
                  style: mgTextStyle(c, size: MgType.small, color: c.fg2),
                ),
              ],
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
                      label: l10n.pollCreate,
                      filled: true,
                      onTap: _create,
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

/// One option: in quiz mode a radio for the right answer, the field, and
/// a cross to drop it.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.controller,
    required this.hint,
    required this.quiz,
    required this.correct,
    required this.onCorrect,
    required this.onRemove,
    required this.removeTooltip,
    required this.correctTooltip,
  });

  final TextEditingController controller;
  final String hint;
  final bool quiz;
  final bool correct;
  final VoidCallback onCorrect;
  final VoidCallback? onRemove;
  final String removeTooltip;
  final String correctTooltip;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Row(
      children: [
        if (quiz)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: correctTooltip,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCorrect,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: correct ? c.accent : const Color(0x00000000),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: correct
                            ? c.accent
                            : c.fg2.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                    ),
                    child: correct
                        ? MgIcon(
                            MgIcons.check,
                            size: 12,
                            color: c.onAccent,
                            stroke: 2.4,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: MgUnderlineField(
            controller: controller,
            hintText: hint,
            fontSize: 14,
          ),
        ),
        SizedBox(
          width: 28,
          child: onRemove == null
              ? null
              : MgIconButton(
                  icon: MgIcons.close,
                  tooltip: removeTooltip,
                  iconSize: 13,
                  onPressed: onRemove,
                ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    // The whole row takes the click, as a System Settings row does.
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: mgTextStyle(c, color: enabled ? c.fg : c.fg2),
                ),
              ),
              Opacity(
                opacity: enabled ? 1 : 0.5,
                child: MgSwitch(value: value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
