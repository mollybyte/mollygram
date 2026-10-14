import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

void main() {
  Workspace w() => Workspace.initial();

  group('open', () {
    test('puts a chat into the focused pane of an empty tab', () {
      final s = w().open(1);
      expect(s.tabs, hasLength(1));
      expect(s.activeTab.panes, [1]);
    });

    test('replaces the focused chat', () {
      final s = w().open(1).open(2);
      expect(s.activeTab.panes, [2]);
    });

    test('switches to a chat that is already open in another tab', () {
      final s = w().open(1).open(2, target: OpenTarget.newTab).open(1);
      expect(s.tabs, hasLength(2));
      expect(s.active, 0);
      expect(s.focusedChat, 1);
    });

    test('in split view, focuses the other pane if the chat is there', () {
      final s = w().open(1).open(2, target: OpenTarget.split).focusPane(0);
      final again = s.open(2);
      expect(again.activeTab.focus, 1);
      expect(again.activeTab.panes, [1, 2]);
    });

    test('split adds a second pane and focuses it', () {
      final s = w().open(1).open(2, target: OpenTarget.split);
      expect(s.activeTab.panes, [1, 2]);
      expect(s.activeTab.focus, 1);
    });

    test('split replaces the unfocused pane when already split', () {
      final s = w()
          .open(1)
          .open(2, target: OpenTarget.split)
          .focusPane(0)
          .open(3, target: OpenTarget.split);
      expect(s.activeTab.panes, [1, 3]);
      expect(s.activeTab.focus, 1);
    });

    test('split with the only chat of the tab changes nothing', () {
      final s = w().open(1);
      expect(s.open(1, target: OpenTarget.split), s);
    });

    test('new tab goes right after the active one', () {
      final s = w()
          .open(1)
          .open(2, target: OpenTarget.newTab)
          .selectTab(0)
          .open(3, target: OpenTarget.newTab);
      expect([for (final t in s.tabs) t.panes.single], [1, 3, 2]);
      expect(s.active, 1);
    });

    test('new tab reuses an empty tab', () {
      final s = w().open(1, target: OpenTarget.newTab);
      expect(s.tabs, hasLength(1));
      expect(s.focusedChat, 1);
    });

    test('a new tab for an open chat switches to it', () {
      final s = w().open(1).open(2, target: OpenTarget.newTab);
      final again = s.open(1, target: OpenTarget.newTab);
      expect(again.tabs, hasLength(2));
      expect(again.active, 0);
    });
  });

  group('tabs', () {
    Workspace three() => w()
        .open(1)
        .open(2, target: OpenTarget.newTab)
        .open(3, target: OpenTarget.newTab);

    test('closing the active tab activates the right neighbour', () {
      final s = three().selectTab(1).closeTab(1);
      expect(s.focusedChat, 3);
    });

    test('closing the last active tab activates the left neighbour', () {
      final s = three().closeTab(2);
      expect(s.focusedChat, 2);
    });

    test('closing a tab left of the active one keeps the active chat', () {
      final s = three().closeTab(0);
      expect(s.focusedChat, 3);
      expect(s.active, 1);
    });

    test('closing the only tab leaves one empty tab with a fresh id', () {
      final before = w().open(1);
      final s = before.closeTab(0);
      expect(s.tabs, hasLength(1));
      expect(s.focusedChat, isNull);
      expect(s.activeTab.id, isNot(before.activeTab.id));
    });

    test('close other tabs', () {
      final s = three().selectTab(1).closeOtherTabs(1);
      expect(s.tabs, hasLength(1));
      expect(s.focusedChat, 2);
    });

    test('number shortcuts, 9 is the last tab', () {
      expect(three().selectTabByNumber(1).active, 0);
      expect(three().selectTabByNumber(9).active, 2);
      expect(three().selectTabByNumber(5).active, 2, reason: 'out of range');
    });

    test('next and previous wrap around', () {
      expect(three().nextTab().active, 0);
      expect(three().selectTab(0).previousTab().active, 2);
    });

    test('moving a tab keeps the active tab active', () {
      final s = three().selectTab(0).moveTab(0, 2);
      expect([for (final t in s.tabs) t.panes.single], [2, 3, 1]);
      expect(s.focusedChat, 1);
    });

    test('tab ids are unique and never reused', () {
      var s = three();
      s = s.closeTab(2).newTab();
      final ids = s.tabs.map((t) => t.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.last, 3);
    });
  });

  group('split view', () {
    test('toggle turns split on with an empty focused pane', () {
      final s = w().open(1).toggleSplit();
      expect(s.activeTab.panes, [1, null]);
      expect(s.activeTab.focus, 1);
      expect(s.open(2).activeTab.panes, [1, 2]);
    });

    test('toggle off keeps the focused chat', () {
      final s = w().open(1).open(2, target: OpenTarget.split).focusPane(0);
      expect(s.toggleSplit().activeTab.panes, [1]);
    });

    test('close focused closes a pane first, then the tab', () {
      final s = w()
          .open(1)
          .open(2, target: OpenTarget.newTab)
          .open(3, target: OpenTarget.split);
      final one = s.closeFocused();
      expect(one.tabs, hasLength(2));
      expect(one.activeTab.panes, [2]);
      final two = one.closeFocused();
      expect(two.tabs, hasLength(1));
      expect(two.focusedChat, 1);
    });

    test('swap mirrors panes, focus and divider', () {
      final s = w()
          .open(1)
          .open(2, target: OpenTarget.split)
          .setSplit(0.3)
          .swapPanes();
      expect(s.activeTab.panes, [2, 1]);
      expect(s.activeTab.focus, 0);
      expect(s.activeTab.split, closeTo(0.7, 1e-9));
    });

    test('divider is clamped', () {
      final s = w().open(1).open(2, target: OpenTarget.split);
      expect(s.setSplit(0).activeTab.split, WorkspaceTab.minSplit);
      expect(s.setSplit(1).activeTab.split, WorkspaceTab.maxSplit);
    });

    test('divider does nothing without a split', () {
      final s = w().open(1);
      expect(s.setSplit(0.3), s);
    });
  });

  group('removeChat', () {
    test('closes its pane in a split and empties a single tab', () {
      final s = w()
          .open(1)
          .open(2, target: OpenTarget.split)
          .open(1, target: OpenTarget.current)
          .open(3, target: OpenTarget.newTab)
          .open(1, target: OpenTarget.split);
      final r = s.removeChat(1);
      expect(r.tabs[0].panes, [2]);
      expect(r.tabs[1].panes, [3]);
      expect(w().open(1).removeChat(1).activeTab.panes, [null]);
    });
  });

  group('json', () {
    test('round trips', () {
      final s = w()
          .open(1)
          .open(2, target: OpenTarget.split)
          .setSplit(0.35)
          .open(3, target: OpenTarget.newTab);
      final restored = Workspace.fromJson(s.toJson());
      expect(restored, s);
      // Ids keep growing after a restore.
      final next = restored.newTab();
      expect(
        next.activeTab.id,
        greaterThan(s.tabs.map((t) => t.id).reduce((a, b) => a > b ? a : b)),
      );
    });

    test('malformed input falls back to the initial layout', () {
      expect(Workspace.fromJson(null), Workspace.initial());
      expect(Workspace.fromJson({'tabs': 'x'}), Workspace.initial());
      expect(Workspace.fromJson({'tabs': <Object>[]}), Workspace.initial());
    });

    test('bad values are repaired', () {
      final s = Workspace.fromJson({
        'active': 7,
        'tabs': [
          {
            'id': 1,
            'panes': [5, 5],
            'focus': 1,
            'split': 3,
          },
          {
            'id': 1,
            'panes': [6],
          },
          {
            'id': 2,
            'panes': [7, 8, 9],
          },
        ],
      });
      expect(s.tabs, hasLength(1));
      expect(s.activeTab.panes, [5]);
      expect(s.activeTab.focus, 0);
      expect(s.active, 0);
    });
  });

  test('controller notifies on change', () {
    final c = WorkspaceController();
    var calls = 0;
    c.addListener(() => calls++);
    c.open(1);
    c.open(1);
    c.newTab();
    expect(calls, 2);
    c.dispose();
  });
}
