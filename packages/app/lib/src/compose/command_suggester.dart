import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// Watches the draft for a `/command` and offers the commands the chat's
/// bots announce; [pick] sends the chosen one through [onSend].
class CommandSuggester extends ChangeNotifier {
  CommandSuggester({required this.controller, required this.onSend}) {
    controller.addListener(_changed);
  }

  final RichTextEditingController controller;
  final void Function(String command) onSend;

  /// The commands of the current chat; set by the chat.
  List<BotCommand> commands = const [];

  List<BotCommand> _found = const [];
  List<ComposerSuggestion> _suggestions = const [];
  String? _query;
  String? _dismissed;
  var _disposed = false;

  List<ComposerSuggestion> get suggestions => _suggestions;

  void _changed() => refresh();

  /// Looks at the draft again, also after the commands changed.
  void refresh() {
    final query = commands.isEmpty ? null : controller.commandQuery;
    if (query == _query && _found.length == _matches(query).length) return;
    _query = query;
    if (query == null || query == _dismissed) {
      _dismissed = query == null ? null : _dismissed;
      _set(const []);
      return;
    }
    _dismissed = null;
    _set(_matches(query));
  }

  List<BotCommand> _matches(String? query) => query == null
      ? const []
      : [
          for (final command in commands)
            if (command.command.toLowerCase().startsWith(query.toLowerCase()))
              command,
        ].take(8).toList();

  void _set(List<BotCommand> found) {
    if (_disposed) return;
    if (found.isEmpty && _found.isEmpty) return;
    _found = found;
    _suggestions = [
      for (final command in found)
        ComposerSuggestion(
          title: '/${command.command}',
          subtitle: command.description,
        ),
    ];
    notifyListeners();
  }

  /// Sends command [index] and empties the draft.
  void pick(int index) {
    if (index < 0 || index >= _found.length) return;
    final command = _found[index].command;
    _set(const []);
    controller.clear();
    onSend('/$command');
  }

  /// Esc: hides the popup until the word changes.
  void dismiss() {
    _dismissed = _query;
    _set(const []);
  }

  void reset() {
    _dismissed = null;
    _query = null;
    _set(const []);
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_changed);
    super.dispose();
  }
}
