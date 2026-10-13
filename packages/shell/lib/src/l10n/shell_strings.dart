import 'dart:ui';

/// User-facing strings of the shell, in English and Russian.
///
/// Both languages implement the same interface, so a string missing in one
/// of them is a compile error rather than a gap in the UI.
abstract interface class ShellStrings {
  static const ShellStrings en = _En();
  static const ShellStrings ru = _Ru();

  /// Russian for `ru`, English for everything else.
  static ShellStrings forLocale(Locale? locale) =>
      locale?.languageCode == 'ru' ? ru : en;

  String get palette;
  String get palettePlaceholder;
  String get paletteSearchLabel;
  String get paletteResults;
  String get nothingFound;

  String get hintOpen;
  String get hintSplit;
  String get hintNewTab;
  String get hintPrefixes;

  String get groupRecent;
  String get groupChats;
  String get groupPeople;
  String get groupMessages;
  String get groupCommands;

  String newMessages(int count);

  String get tabs;
  String get newTab;
  String get closeTab;
  String get emptyPane;
  String get splitDivider;

  String get cmdNewTab;
  String get cmdCloseTab;
  String get cmdCloseOtherTabs;
  String get cmdNextTab;
  String get cmdPreviousTab;
  String get cmdSplit;
  String get cmdCloseSplit;
  String get cmdSwapPanes;
}

class _En implements ShellStrings {
  const _En();

  @override
  String get palette => 'Command palette';
  @override
  String get palettePlaceholder => 'Chats, messages and commands';
  @override
  String get paletteSearchLabel => 'Search the palette';
  @override
  String get paletteResults => 'Results';
  @override
  String get nothingFound => 'Nothing found';

  @override
  String get hintOpen => 'open';
  @override
  String get hintSplit => 'in split view';
  @override
  String get hintNewTab => 'in a new tab';
  @override
  String get hintPrefixes => '> commands · @ people · # messages';

  @override
  String get groupRecent => 'Recent';
  @override
  String get groupChats => 'Chats';
  @override
  String get groupPeople => 'People';
  @override
  String get groupMessages => 'Messages';
  @override
  String get groupCommands => 'Commands';

  @override
  String newMessages(int count) => '$count new';

  @override
  String get tabs => 'Tabs';
  @override
  String get newTab => 'New tab';
  @override
  String get closeTab => 'Close tab';
  @override
  String get emptyPane => 'Select a chat';
  @override
  String get splitDivider => 'Split view divider';

  @override
  String get cmdNewTab => 'New tab';
  @override
  String get cmdCloseTab => 'Close tab';
  @override
  String get cmdCloseOtherTabs => 'Close other tabs';
  @override
  String get cmdNextTab => 'Next tab';
  @override
  String get cmdPreviousTab => 'Previous tab';
  @override
  String get cmdSplit => 'Open second chat in split view';
  @override
  String get cmdCloseSplit => 'Close split view';
  @override
  String get cmdSwapPanes => 'Swap chats in split view';
}

class _Ru implements ShellStrings {
  const _Ru();

  @override
  String get palette => 'Командная палитра';
  @override
  String get palettePlaceholder => 'Чаты, сообщения и команды';
  @override
  String get paletteSearchLabel => 'Поиск по палитре';
  @override
  String get paletteResults => 'Результаты';
  @override
  String get nothingFound => 'Ничего не нашлось';

  @override
  String get hintOpen => 'открыть';
  @override
  String get hintSplit => 'в сплите';
  @override
  String get hintNewTab => 'во вкладке';
  @override
  String get hintPrefixes => '> команды · @ люди · # сообщения';

  @override
  String get groupRecent => 'Недавние';
  @override
  String get groupChats => 'Чаты';
  @override
  String get groupPeople => 'Люди';
  @override
  String get groupMessages => 'Сообщения';
  @override
  String get groupCommands => 'Команды';

  @override
  String newMessages(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    final word = mod10 == 1 && mod100 != 11 ? 'новое' : 'новых';
    return '$count $word';
  }

  @override
  String get tabs => 'Вкладки';
  @override
  String get newTab => 'Новая вкладка';
  @override
  String get closeTab => 'Закрыть вкладку';
  @override
  String get emptyPane => 'Выберите чат';
  @override
  String get splitDivider => 'Разделитель сплита';

  @override
  String get cmdNewTab => 'Новая вкладка';
  @override
  String get cmdCloseTab => 'Закрыть вкладку';
  @override
  String get cmdCloseOtherTabs => 'Закрыть другие вкладки';
  @override
  String get cmdNextTab => 'Следующая вкладка';
  @override
  String get cmdPreviousTab => 'Предыдущая вкладка';
  @override
  String get cmdSplit => 'Открыть второй чат в сплите';
  @override
  String get cmdCloseSplit => 'Закрыть сплит';
  @override
  String get cmdSwapPanes => 'Поменять чаты местами';
}
