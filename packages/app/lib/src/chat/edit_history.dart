import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../home/format.dart';
import '../profile/manage_sheet.dart';
import 'describe.dart';
import 'load_spinner.dart';

/// Opens the earlier versions of [message], as the privacy store kept
/// them, under the version that stands now.
Future<void> showEditHistory(
  BuildContext context, {
  required ConversationMessage message,
  required Future<List<MessageVersion>> versions,
}) => showManageSheet<void>(
  context,
  EditHistorySheet(message: message, versions: versions),
);

/// The versions of an edited message, oldest first, each with when it
/// was written; the current one closes the list.
class EditHistorySheet extends StatelessWidget {
  const EditHistorySheet({
    super.key,
    required this.message,
    required this.versions,
  });

  final ConversationMessage message;
  final Future<List<MessageVersion>> versions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ManageSheetFrame(
      title: l10n.editHistoryTitle,
      height: 420,
      child: FutureBuilder<List<MessageVersion>>(
        future: versions,
        builder: (context, snapshot) {
          final earlier = snapshot.data;
          if (earlier == null) return const Center(child: LoadSpinner());
          if (earlier.isEmpty) {
            return Center(child: DatePill(l10n.editHistoryEmpty));
          }
          final locale = Localizations.localeOf(context).toLanguageTag();
          final editDate = message.editDate > 0
              ? message.editDate
              : message.date;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              for (final version in earlier)
                _VersionRow(
                  key: ValueKey(
                    'version-${version.replacedAt.millisecondsSinceEpoch}',
                  ),
                  when: formatFullDate(
                    version.date.millisecondsSinceEpoch ~/ 1000,
                    locale,
                  ),
                  text: _textOf(l10n, version.content),
                ),
              _VersionRow(
                key: const ValueKey('version-current'),
                when: formatFullDate(editDate, locale),
                label: l10n.editHistoryCurrent,
                text: _textOf(l10n, message.content),
                current: true,
              ),
            ],
          );
        },
      ),
    );
  }

  static String _textOf(AppLocalizations l10n, td.MessageContent content) {
    final caption = captionOf(content)?.text ?? '';
    if (caption.isNotEmpty) return caption;
    return describeContent(l10n, content);
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    super.key,
    required this.when,
    required this.text,
    this.label,
    this.current = false,
  });

  final String when;
  final String text;
  final String? label;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                when,
                style: mgTextStyle(c, size: 12, color: c.fg2, height: 1.3),
              ),
              if (label case final label?) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: mgTextStyle(
                    c,
                    size: 12,
                    weight: FontWeight.w600,
                    color: c.accent,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            text,
            style: mgTextStyle(
              c,
              size: 13,
              color: current ? c.fg : c.fg2,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
