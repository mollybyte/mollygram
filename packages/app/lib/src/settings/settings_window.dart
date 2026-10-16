import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../notifications/notifications_page.dart';
import '../window_drag_area.dart';
import 'account_page.dart';
import 'appearance_page.dart';
import 'folders_page.dart';
import 'language_page.dart';
import 'plugins_page.dart';
import 'privacy/privacy_page.dart';
import 'privacy_extras_page.dart';
import 'proxy_page.dart';
import 'settings_style.dart';
import 'shortcuts/shortcuts_page.dart';
import 'stickers/stickers_page.dart';
import 'storage_page.dart';

/// One entry of the settings source list and the page it opens.
///
/// Adding a page is adding a descriptor to [settingsSections].
@immutable
class SettingsSection {
  const SettingsSection({
    required this.id,
    required this.icon,
    required this.tint,
    required this.title,
    required this.builder,
    this.keywords = _noKeywords,
    this.fullBleed = false,
  });

  /// A stable id, used to open the window on this section.
  final String id;
  final MgIconData icon;

  /// The tile color behind [icon].
  final Color tint;
  final String Function(AppLocalizations l10n) title;

  /// Extra words the search matches, besides the title in both languages.
  final List<String> Function(AppLocalizations l10n) keywords;

  /// The page shown in the content pane.
  final WidgetBuilder builder;

  /// The page fills the pane edge to edge and brings its own title bar,
  /// like the notifications page.
  final bool fullBleed;

  static List<String> _noKeywords(AppLocalizations l10n) => const [];
}

/// The account card at the top of the source list opens this page.
const accountSectionId = 'account';

/// Ghost mode and the other privacy extras.
const privacyExtrasSectionId = 'privacyExtras';

/// Every page of the source list below the account card, in order.
final settingsSections = <SettingsSection>[
  SettingsSection(
    id: 'notifications',
    icon: MgIcons.notifications,
    tint: const Color(0xFFE5343B),
    title: (l10n) => l10n.notifications,
    builder: (context) => const NotificationsPage(),
  ),
  SettingsSection(
    id: 'privacy',
    icon: MgIcons.lock,
    tint: const Color(0xFF0A7CFF),
    title: (l10n) => l10n.privacyAndSecurity,
    keywords: (l10n) => [
      l10n.activeSessions,
      l10n.thisDevice,
      l10n.terminateOthers,
      l10n.blockedUsers,
      for (final rule in privacyPageRules) rule.title(l10n),
    ],
    builder: (context) => const PrivacySecurityPage(),
  ),
  SettingsSection(
    id: privacyExtrasSectionId,
    icon: MgIcons.ghost,
    tint: const Color(0xFF6E6E80),
    title: (l10n) => l10n.privacyExtras,
    keywords: (l10n) => [
      l10n.ghostMode,
      l10n.hideReadReceipts,
      l10n.hideTyping,
      l10n.stayOffline,
      l10n.hideContentOpened,
      l10n.keepDeletedMessages,
      l10n.keepEditHistory,
      l10n.allowSecretScreenshots,
    ],
    builder: (context) => const PrivacyExtrasPage(),
  ),
  SettingsSection(
    id: 'data',
    icon: MgIcons.storage,
    tint: const Color(0xFF34A853),
    title: (l10n) => l10n.dataAndStorage,
    keywords: (l10n) => [
      l10n.storageUsage,
      l10n.clearCache,
      l10n.autoDownload,
      l10n.downloadFolder,
    ],
    builder: (context) => const StoragePage(),
  ),
  proxySection,
  SettingsSection(
    id: 'appearance',
    icon: MgIcons.appearance,
    tint: const Color(0xFF5E5CE6),
    title: (l10n) => l10n.appearance,
    keywords: (l10n) => [
      l10n.themeDark,
      l10n.themeLight,
      l10n.accentColor,
      l10n.chatBackground,
      l10n.nightSchedule,
      l10n.messageTextSize,
      l10n.mediaCorners,
      l10n.compactLayout,
      l10n.appIcon,
      l10n.reduceMotion,
    ],
    builder: (context) => const AppearancePage(),
  ),
  foldersSection,
  languageSection,
  stickersSection,
  shortcutsSection,
  SettingsSection(
    id: 'plugins',
    icon: MgIcons.plugin,
    tint: const Color(0xFF8E8E93),
    title: (l10n) => l10n.plugins,
    builder: (context) => const PluginsPage(),
  ),
];

final _accountSection = SettingsSection(
  id: accountSectionId,
  icon: MgIcons.profile,
  tint: const Color(0xFF8E8E93),
  title: (l10n) => l10n.myProfile,
  keywords: (l10n) => [
    l10n.firstName,
    l10n.lastName,
    l10n.username,
    l10n.bio,
    l10n.phoneNumber,
    l10n.logOut,
  ],
  builder: (context) => const AccountPage(),
);

/// Whether [section] matches the search [query], in either language.
bool settingsSectionMatches(
  SettingsSection section,
  String query,
  List<AppLocalizations> languages,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  for (final l10n in languages) {
    for (final word in [section.title(l10n), ...section.keywords(l10n)]) {
      if (word.toLowerCase().contains(q)) return true;
    }
  }
  return false;
}

/// Lets a page open a page of its own in the content pane, such as
/// Privacy and security opening Active sessions.
class SettingsNavigation extends InheritedWidget {
  const SettingsNavigation({
    super.key,
    required this.push,
    required super.child,
  });

  /// Shows the page built by [builder] under [title], with a back button.
  final void Function(String title, WidgetBuilder builder) push;

  static SettingsNavigation of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsNavigation>()!;

  @override
  bool updateShouldNotify(SettingsNavigation old) => false;
}

/// The settings over the whole window, styled like macOS System Settings:
/// the source list on the left, the selected page on the right. Esc goes
/// back from a nested page, then closes.
class SettingsWindow extends ConsumerStatefulWidget {
  const SettingsWindow({
    super.key,
    required this.onClose,
    this.initialSection = accountSectionId,
  });

  final VoidCallback onClose;
  final String initialSection;

  /// Width of the source list.
  static const sidebarWidth = 236.0;

  /// Height of the title bar band, where the window buttons sit:
  /// TelegramSwift's navigation bar.
  static const titleBarHeight = 50.0;

  /// Top of the back and close buttons (32 tall), centred on the band.
  static const _buttonTop = (titleBarHeight - 32) / 2;

  @override
  ConsumerState<SettingsWindow> createState() => _SettingsWindowState();
}

class _NestedPage {
  const _NestedPage(this.title, this.builder);

  final String title;
  final WidgetBuilder builder;
}

class _SettingsWindowState extends ConsumerState<SettingsWindow>
    with SingleTickerProviderStateMixin {
  late final _appear = AnimationController(vsync: this);
  final _search = TextEditingController();
  late String _section = widget.initialSection;
  final _nested = <_NestedPage>[];
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appear.duration = settingsMotionOf(context);
    if (_appear.isDismissed && !_closing) _appear.forward();
  }

  @override
  void dispose() {
    _appear.dispose();
    _search.dispose();
    super.dispose();
  }

  SettingsSection get _current => _sectionById(_section);

  SettingsSection _sectionById(String id) => id == accountSectionId
      ? _accountSection
      : settingsSections.firstWhere(
          (s) => s.id == id,
          orElse: () => _accountSection,
        );

  void _select(String id) {
    if (id == _section && _nested.isEmpty) return;
    setState(() {
      _section = id;
      _nested.clear();
    });
  }

  void _push(String title, WidgetBuilder builder) =>
      setState(() => _nested.add(_NestedPage(title, builder)));

  void _back() => setState(_nested.removeLast);

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _appear.reverse();
    if (mounted) widget.onClose();
  }

  void _escape() => _nested.isNotEmpty ? _back() : _close();

  List<AppLocalizations> _languages(AppLocalizations l10n) => [
    l10n,
    lookupAppLocalizations(Locale(l10n.localeName == 'ru' ? 'en' : 'ru')),
  ];

  /// Enter in the search field opens the first match.
  void _openFirstMatch(List<SettingsSection> matches) {
    if (matches.isNotEmpty) _select(matches.first.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = SettingsColors.of(context);
    final l10n = AppLocalizations.of(context);
    final languages = _languages(l10n);
    final query = _search.text;
    final accountMatches = settingsSectionMatches(
      _accountSection,
      query,
      languages,
    );
    final matches = [
      if (accountMatches) _accountSection,
      for (final section in settingsSections)
        if (settingsSectionMatches(section, query, languages)) section,
    ];
    final section = _current;
    final page = _nested.isEmpty ? null : _nested.last;
    final title = page?.title ?? section.title(l10n);
    final pageKey = '${section.id}/${_nested.length}';

    // Laid out as the chats' sidebar, so the window buttons sit in the
    // same place: a title row over the search field, on the frame.
    final sidebar = ColoredBox(
      color: s.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            height: SidebarIsland.topInset + SidebarIsland.titleBarHeight,
            child: WindowDragArea(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: MgSearchField(
              hintText: l10n.settingsSearch,
              controller: _search,
              onSubmitted: (_) => _openFirstMatch(matches),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: [
                if (accountMatches)
                  AccountCard(
                    selected: _section == accountSectionId,
                    onTap: () => _select(accountSectionId),
                  ),
                if (accountMatches) const SizedBox(height: 10),
                for (final item in settingsSections)
                  if (matches.contains(item))
                    _SidebarItem(
                      key: ValueKey(item.id),
                      section: item,
                      selected: _section == item.id,
                      onTap: () => _select(item.id),
                    ),
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      l10n.nothingFound,
                      textAlign: TextAlign.center,
                      style: mgTextStyle(c, color: c.fg2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final body = page?.builder(context) ?? section.builder(context);
    final Widget content;
    if (section.fullBleed && page == null) {
      content = body;
    } else {
      content = ColoredBox(
        color: s.pane,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: SettingsWindow.titleBarHeight,
              child: Padding(
                // The close button sits over the right end.
                padding: const EdgeInsets.only(right: 48),
                // The back button is drawn over this band, above the window
                // drag area (see the pane below); the title makes room.
                child: AnimatedPadding(
                  duration: settingsMotionOf(context),
                  curve: settingsCurve,
                  padding: EdgeInsets.only(left: _nested.isEmpty ? 20 : 46),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(
                          c,
                          size: MgType.title,
                          weight: MgWeight.medium,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }
    final pane = Stack(
      children: [
        Positioned.fill(
          child: _PageSwitcher(pageKey: pageKey, child: content),
        ),
        // The title bar is hidden: the band drags the window. The back and
        // close buttons are painted above it, so they take the clicks.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 38,
          child: WindowDragArea(),
        ),
        if (_nested.isNotEmpty)
          Positioned(
            top: SettingsWindow._buttonTop,
            left: 10,
            child: MgIconButton(
              icon: MgIcons.back,
              tooltip: l10n.back,
              onPressed: _back,
            ),
          ),
        Positioned(
          top: SettingsWindow._buttonTop,
          right: 10,
          child: MgIconButton(
            icon: MgIcons.close,
            tooltip: l10n.close,
            onPressed: _close,
          ),
        ),
      ],
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
      child: FocusScope(
        autofocus: true,
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _appear, curve: settingsCurve),
          child: ScaleTransition(
            scale: Tween(
              begin: 0.985,
              end: 1.0,
            ).animate(CurvedAnimation(parent: _appear, curve: settingsCurve)),
            child: ColoredBox(
              color: s.sidebar,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: SettingsWindow.sidebarWidth, child: sidebar),
                  // The page lies on a card, as a chat does.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        SidebarIsland.topInset,
                        SidebarIsland.topInset,
                        SidebarIsland.topInset,
                      ),
                      child: ChatCard(
                        background: ColoredBox(color: s.pane),
                        child: SettingsNavigation(push: _push, child: pane),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cross-fades from one page to the next with a slight rise, so switching
/// sections feels like the pane settling rather than a cut.
class _PageSwitcher extends StatelessWidget {
  const _PageSwitcher({required this.pageKey, required this.child});

  /// Changes when another page is shown; a rebuilt page keeps it.
  final String pageKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: settingsMotionOf(context),
    switchInCurve: settingsCurve,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) =>
        Stack(fit: StackFit.expand, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.008),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: KeyedSubtree(key: ValueKey(pageKey), child: child),
  );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    super.key,
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: MgPressable(
        scale: 1,
        onTap: onTap,
        builder: (context, state) => SettingsSidebarTile(
          selected: selected,
          hover: state.hovered,
          pressed: state.pressed,
          height: 34,
          child: Row(
            children: [
              SettingsSymbol(icon: section.icon, tint: section.tint),
              const SizedBox(width: MgSpace.ml),
              Expanded(
                child: Text(
                  section.title(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(
                    c,
                    color: selected ? c.onAccent : null,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rounded highlight of a source list entry: the accent when selected,
/// a faint fill on hover.
class SettingsSidebarTile extends StatelessWidget {
  const SettingsSidebarTile({
    super.key,
    required this.selected,
    required this.hover,
    this.pressed = false,
    required this.height,
    required this.child,
  });

  final bool selected;
  final bool hover;

  /// Held down: a shade deeper than hover, before the click selects it.
  final bool pressed;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return AnimatedContainer(
      duration: pressed ? MgMotion.press : const Duration(milliseconds: 120),
      curve: settingsCurve,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: selected
            ? c.accent
            : pressed
            ? Color.alphaBlend(c.hover, c.hover)
            : hover
            ? c.hover
            : c.accent.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(MgRadius.control),
      ),
      child: child,
    );
  }
}
