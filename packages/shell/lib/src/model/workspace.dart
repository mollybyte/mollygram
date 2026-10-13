import 'package:flutter/foundation.dart';

/// A Telegram chat id. Mirrors TDLib's `int53` chat ids.
typedef ChatId = int;

/// Where [Workspace.open] puts a chat.
enum OpenTarget {
  /// The focused pane of the active tab (⏎).
  current,

  /// The other half of a split view, created if needed (⌘⏎).
  split,

  /// A new tab after the active one (⌥⏎).
  newTab,
}

/// One tab of the window: one chat, or two chats side by side.
///
/// A pane holds `null` while it waits for a chat to be picked, for example
/// right after the split view is turned on.
@immutable
class WorkspaceTab {
  const WorkspaceTab({
    required this.id,
    required this.panes,
    this.focus = 0,
    this.split = defaultSplit,
  }) : assert(panes.length == 1 || panes.length == 2),
       assert(focus >= 0 && focus < panes.length);

  /// Starting share of the window width that the left pane gets.
  static const double defaultSplit = 0.5;

  /// The divider never leaves this range, so neither pane collapses.
  static const double minSplit = 0.2;
  static const double maxSplit = 0.8;

  /// Stable id for widget keys; never reused within one [Workspace].
  final int id;

  /// One or two panes, left to right.
  final List<ChatId?> panes;

  /// Index of the pane that receives keyboard input and new chats.
  final int focus;

  /// Share of the width given to the left pane in a split view.
  final double split;

  bool get isSplit => panes.length == 2;

  ChatId? get focusedChat => panes[focus];

  bool contains(ChatId chat) => panes.contains(chat);

  WorkspaceTab copyWith({List<ChatId?>? panes, int? focus, double? split}) {
    return WorkspaceTab(
      id: id,
      panes: List.unmodifiable(panes ?? this.panes),
      focus: focus ?? this.focus,
      split: split ?? this.split,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'panes': panes,
    'focus': focus,
    'split': split,
  };

  @override
  bool operator ==(Object other) =>
      other is WorkspaceTab &&
      other.id == id &&
      listEquals(other.panes, panes) &&
      other.focus == focus &&
      other.split == split;

  @override
  int get hashCode => Object.hash(id, Object.hashAll(panes), focus, split);

  @override
  String toString() => 'WorkspaceTab($id, $panes, focus: $focus)';
}

/// The window layout: a row of tabs, each with one or two panes.
///
/// Replaces route-based navigation. Every operation returns a new value and
/// keeps the invariants: at least one tab, a valid active index, one or two
/// panes per tab, and no chat shown twice inside one tab.
@immutable
class Workspace {
  Workspace._(List<WorkspaceTab> tabs, this.active, this._nextId)
    : tabs = List.unmodifiable(tabs),
      assert(tabs.isNotEmpty),
      assert(active >= 0 && active < tabs.length);

  /// A single empty tab.
  factory Workspace.initial() => Workspace._(
    [
      WorkspaceTab(id: 0, panes: const [null]),
    ],
    0,
    1,
  );

  /// Restores a layout saved with [toJson]. Anything malformed falls back to
  /// [Workspace.initial], so a broken file never keeps the window from
  /// opening.
  factory Workspace.fromJson(Object? json) {
    try {
      final map = json! as Map<String, Object?>;
      final tabs = <WorkspaceTab>[];
      final seen = <int>{};
      for (final raw in map['tabs']! as List<Object?>) {
        final t = raw! as Map<String, Object?>;
        final id = t['id']! as int;
        final panes = [for (final p in t['panes']! as List<Object?>) p as int?];
        if (!seen.add(id) || panes.isEmpty || panes.length > 2) continue;
        if (panes.length == 2 && panes[0] != null && panes[0] == panes[1]) {
          panes.removeLast();
        }
        final focus = (t['focus'] as int? ?? 0).clamp(0, panes.length - 1);
        final split =
            ((t['split'] as num?)?.toDouble() ?? WorkspaceTab.defaultSplit)
                .clamp(WorkspaceTab.minSplit, WorkspaceTab.maxSplit);
        tabs.add(
          WorkspaceTab(
            id: id,
            panes: List.unmodifiable(panes),
            focus: focus,
            split: split,
          ),
        );
      }
      if (tabs.isEmpty) return Workspace.initial();
      final active = (map['active'] as int? ?? 0).clamp(0, tabs.length - 1);
      final nextId = tabs.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
      return Workspace._(tabs, active, nextId);
    } on Object {
      return Workspace.initial();
    }
  }

  final List<WorkspaceTab> tabs;

  /// Index of the visible tab.
  final int active;

  final int _nextId;

  WorkspaceTab get activeTab => tabs[active];

  /// The chat that has keyboard focus, if any.
  ChatId? get focusedChat => activeTab.focusedChat;

  Map<String, Object?> toJson() => {
    'tabs': [for (final t in tabs) t.toJson()],
    'active': active,
  };

  /// Shows [chat] according to [target].
  ///
  /// A chat that is already open is brought forward instead of being opened
  /// a second time, except for [OpenTarget.split], which only avoids
  /// duplicates inside the active tab.
  Workspace open(ChatId chat, {OpenTarget target = OpenTarget.current}) {
    switch (target) {
      case OpenTarget.current:
        final existing = _find(chat);
        if (existing != null) return _reveal(existing);
        final tab = activeTab;
        final panes = [...tab.panes];
        panes[tab.focus] = chat;
        return _replaceActive(tab.copyWith(panes: panes));

      case OpenTarget.split:
        final tab = activeTab;
        final inTab = tab.panes.indexOf(chat);
        if (inTab >= 0) {
          if (tab.isSplit) return _replaceActive(tab.copyWith(focus: inTab));
          // The only chat of this tab: there is nothing to put next to it.
          return this;
        }
        if (!tab.isSplit) {
          return _replaceActive(
            tab.copyWith(panes: [tab.panes.single, chat], focus: 1),
          );
        }
        final other = 1 - tab.focus;
        final panes = [...tab.panes];
        panes[other] = chat;
        return _replaceActive(tab.copyWith(panes: panes, focus: other));

      case OpenTarget.newTab:
        final existing = _find(chat);
        if (existing != null) return _reveal(existing);
        // An empty single tab is reused rather than left behind.
        if (!activeTab.isSplit && activeTab.focusedChat == null) {
          return _replaceActive(activeTab.copyWith(panes: [chat]));
        }
        return _insertTab(WorkspaceTab(id: _nextId, panes: [chat]));
    }
  }

  /// Opens an empty tab after the active one, ready for a chat.
  Workspace newTab() => _insertTab(WorkspaceTab(id: _nextId, panes: [null]));

  /// Closes the tab at [index]. Closing the last tab leaves one empty tab.
  ///
  /// Like a browser, closing the active tab activates its right neighbour,
  /// or the left one when it was the last.
  Workspace closeTab(int index) {
    if (index < 0 || index >= tabs.length) return this;
    if (tabs.length == 1) {
      return Workspace._(
        [
          WorkspaceTab(id: _nextId, panes: [null]),
        ],
        0,
        _nextId + 1,
      );
    }
    final next = [...tabs]..removeAt(index);
    var active = this.active;
    if (index < active || (index == active && index == next.length)) {
      active -= 1;
    }
    return Workspace._(next, active, _nextId);
  }

  /// Closes every tab except the one at [index].
  Workspace closeOtherTabs(int index) {
    if (index < 0 || index >= tabs.length) return this;
    return Workspace._([tabs[index]], 0, _nextId);
  }

  /// ⌘W: closes the focused half of a split view, otherwise the tab.
  Workspace closeFocused() =>
      activeTab.isSplit ? closePane(activeTab.focus) : closeTab(active);

  /// Removes one pane of the active split view.
  Workspace closePane(int pane) {
    final tab = activeTab;
    if (!tab.isSplit || pane < 0 || pane > 1) return this;
    return _replaceActive(tab.copyWith(panes: [tab.panes[1 - pane]], focus: 0));
  }

  /// ⌘\: turns the split view on with an empty right pane, or off keeping
  /// the focused chat.
  Workspace toggleSplit() {
    final tab = activeTab;
    if (tab.isSplit) return closePane(1 - tab.focus);
    return _replaceActive(
      tab.copyWith(panes: [tab.panes.single, null], focus: 1),
    );
  }

  Workspace swapPanes() {
    final tab = activeTab;
    if (!tab.isSplit) return this;
    return _replaceActive(
      tab.copyWith(
        panes: tab.panes.reversed.toList(),
        focus: 1 - tab.focus,
        split: 1 - tab.split,
      ),
    );
  }

  Workspace focusPane(int pane) {
    final tab = activeTab;
    if (pane < 0 || pane >= tab.panes.length || pane == tab.focus) return this;
    return _replaceActive(tab.copyWith(focus: pane));
  }

  /// Moves the divider of the active split view; [fraction] is clamped.
  Workspace setSplit(double fraction) {
    final tab = activeTab;
    if (!tab.isSplit) return this;
    final value = fraction.clamp(WorkspaceTab.minSplit, WorkspaceTab.maxSplit);
    if (value == tab.split) return this;
    return _replaceActive(tab.copyWith(split: value));
  }

  Workspace selectTab(int index) {
    if (index < 0 || index >= tabs.length || index == active) return this;
    return Workspace._(tabs, index, _nextId);
  }

  /// ⌘1…⌘9. As in browsers, ⌘9 always means the last tab.
  Workspace selectTabByNumber(int number) {
    if (number < 1 || number > 9) return this;
    return selectTab(number == 9 ? tabs.length - 1 : number - 1);
  }

  Workspace nextTab() => selectTab((active + 1) % tabs.length);

  Workspace previousTab() =>
      selectTab((active - 1 + tabs.length) % tabs.length);

  /// Drags the tab at [from] to [to]; the active tab stays active.
  Workspace moveTab(int from, int to) {
    if (from < 0 || from >= tabs.length || to < 0 || to >= tabs.length) {
      return this;
    }
    if (from == to) return this;
    final moving = tabs[from];
    final activeTab = this.activeTab;
    final next = [...tabs]
      ..removeAt(from)
      ..insert(to, moving);
    return Workspace._(next, next.indexOf(activeTab), _nextId);
  }

  /// Takes a chat off screen everywhere, for example after leaving it.
  /// Panes that become empty are closed unless they are a tab's only pane.
  Workspace removeChat(ChatId chat) {
    if (_find(chat) == null) return this;
    var result = this;
    for (var i = result.tabs.length - 1; i >= 0; i--) {
      final tab = result.tabs[i];
      if (!tab.contains(chat)) continue;
      final WorkspaceTab updated;
      if (tab.isSplit) {
        final kept = tab.panes.firstWhere((p) => p != chat);
        updated = tab.copyWith(panes: [kept], focus: 0);
      } else {
        updated = tab.copyWith(panes: [null]);
      }
      final next = [...result.tabs]..[i] = updated;
      result = Workspace._(next, result.active, result._nextId);
    }
    return result;
  }

  ({int tab, int pane})? _find(ChatId chat) {
    // The active tab wins, so a chat open twice is revealed where you are.
    final here = activeTab.panes.indexOf(chat);
    if (here >= 0) return (tab: active, pane: here);
    for (var i = 0; i < tabs.length; i++) {
      final pane = tabs[i].panes.indexOf(chat);
      if (pane >= 0) return (tab: i, pane: pane);
    }
    return null;
  }

  Workspace _reveal(({int tab, int pane}) at) {
    final tab = tabs[at.tab];
    final next = [...tabs]..[at.tab] = tab.copyWith(focus: at.pane);
    return Workspace._(next, at.tab, _nextId);
  }

  Workspace _replaceActive(WorkspaceTab tab) {
    final next = [...tabs]..[active] = tab;
    return Workspace._(next, active, _nextId);
  }

  Workspace _insertTab(WorkspaceTab tab) {
    final next = [...tabs]..insert(active + 1, tab);
    return Workspace._(next, active + 1, _nextId + 1);
  }

  @override
  bool operator ==(Object other) =>
      other is Workspace &&
      other.active == active &&
      listEquals(other.tabs, tabs);

  @override
  int get hashCode => Object.hash(active, Object.hashAll(tabs));

  @override
  String toString() => 'Workspace(active: $active, $tabs)';
}

/// Holds the current [Workspace] and notifies listeners when it changes.
///
/// A thin wrapper so widgets and shortcuts share one source of truth; the
/// app can expose it through its state management of choice.
class WorkspaceController extends ValueNotifier<Workspace> {
  WorkspaceController([Workspace? initial])
    : super(initial ?? Workspace.initial());

  void open(ChatId chat, {OpenTarget target = OpenTarget.current}) =>
      value = value.open(chat, target: target);
  void newTab() => value = value.newTab();
  void closeTab(int index) => value = value.closeTab(index);
  void closeOtherTabs(int index) => value = value.closeOtherTabs(index);
  void closeFocused() => value = value.closeFocused();
  void closePane(int pane) => value = value.closePane(pane);
  void toggleSplit() => value = value.toggleSplit();
  void swapPanes() => value = value.swapPanes();
  void focusPane(int pane) => value = value.focusPane(pane);
  void setSplit(double fraction) => value = value.setSplit(fraction);
  void selectTab(int index) => value = value.selectTab(index);
  void selectTabByNumber(int number) => value = value.selectTabByNumber(number);
  void nextTab() => value = value.nextTab();
  void previousTab() => value = value.previousTab();
  void moveTab(int from, int to) => value = value.moveTab(from, to);
  void removeChat(ChatId chat) => value = value.removeChat(chat);
}
