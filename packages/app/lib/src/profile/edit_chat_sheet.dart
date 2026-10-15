import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/message_tile.dart' show SenderAvatar;
import '../session/providers.dart';
import 'manage_sheet.dart';

/// Edits the title, description and photo of a group or channel. Only
/// what changed is sent; the sheet closes when all of it is saved.
class EditChatSheet extends ConsumerStatefulWidget {
  const EditChatSheet({super.key, required this.info, this.pickPhoto});

  final PeerInfo info;

  /// Asks for an image; the system open panel by default.
  final Future<String?> Function()? pickPhoto;

  @override
  ConsumerState<EditChatSheet> createState() => _EditChatSheetState();
}

/// The photo as the sheet will leave it.
sealed class _Photo {
  const _Photo();
}

final class _Keep extends _Photo {
  const _Keep();
}

final class _Remove extends _Photo {
  const _Remove();
}

final class _Set extends _Photo {
  const _Set(this.path);

  final String path;
}

class _EditChatSheetState extends ConsumerState<EditChatSheet> {
  late final _title = TextEditingController(text: widget.info.title);
  late final _about = TextEditingController(
    text: widget.info.description?.text ?? '',
  );
  _Photo _photo = const _Keep();
  var _busy = false;
  String? _error;
  String? _titleError;

  @override
  void dispose() {
    _title.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<String?> _pick() async {
    if (widget.pickPhoto case final pick?) return pick();
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png']),
      ],
    );
    return file?.path;
  }

  Future<void> _choosePhoto() async {
    final path = await _pick();
    if (path == null || !mounted) return;
    setState(() => _photo = _Set(path));
  }

  /// Enter in a field; ignored while a save is on its way.
  void _submit() {
    if (!_busy) unawaited(_save());
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = l10n.chatTitleRequired);
      return;
    }
    final management = ref
        .read(telegramSessionProvider)
        .requireValue
        .management;
    final id = widget.info.chatId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (title != widget.info.title) await management.setTitle(id, title);
      final about = _about.text.trim();
      if (about != (widget.info.description?.text ?? '').trim()) {
        await management.setDescription(id, about);
      }
      switch (_photo) {
        case _Set(:final path):
          await management.setPhoto(id, path);
        case _Remove():
          await management.setPhoto(id, null);
        case _Keep():
          break;
      }
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.saveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final info = widget.info;
    final channel = info.kind == PeerKind.channel;
    final hasPhoto = switch (_photo) {
      _Keep() => info.photo != null,
      _Remove() => false,
      _Set() => true,
    };
    final avatar = switch (_photo) {
      _Set(:final path) => ClipOval(
        child: Image.file(File(path), width: 72, height: 72, fit: BoxFit.cover),
      ),
      _Remove() => SenderAvatar(name: _title.text, size: 72),
      _Keep() => SenderAvatar(name: info.title, size: 72, photo: info.photo),
    };
    return ManageSheetFrame(
      title: channel ? l10n.editChannel : l10n.editGroup,
      action: l10n.save,
      busy: _busy,
      error: _error,
      onAction: _busy ? null : _save,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: avatar),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MgTextButton(
                  label: hasPhoto ? l10n.changePhoto : l10n.setPhoto,
                  onPressed: _busy ? null : _choosePhoto,
                ),
                if (hasPhoto)
                  MgTextButton(
                    label: l10n.removePhoto,
                    onPressed: _busy
                        ? null
                        : () => setState(() => _photo = const _Remove()),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            MgUnderlineField(
              controller: _title,
              hintText: channel ? l10n.channelName : l10n.groupName,
              autofocus: true,
              fontSize: 14,
              errorText: _titleError,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            MgUnderlineField(
              controller: _about,
              hintText: l10n.descriptionHint,
              fontSize: 14,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.descriptionNote,
              style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
            ),
          ],
        ),
      ),
    );
  }
}
