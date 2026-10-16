import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_host/plugin_host.dart';

import 'colors.dart';
import 'controller.dart';
import 'strings.dart';
import 'widgets.dart';

/// The plugins settings screen, styled like macOS System Settings:
/// design/Plugins.dc.html.
///
/// A glass list over the wallpaper on the left, the selected plugin on a
/// solid pane on the right. Works on its own: it brings its own overlay for
/// menus and the consent sheet.
class PluginsScreen extends StatelessWidget {
  const PluginsScreen({
    super.key,
    required this.controller,
    this.locale = 'en',
    this.brightness,
  });

  final PluginsController controller;

  /// `en` or `ru`.
  final String locale;

  /// Defaults to the platform brightness.
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final dark =
        (brightness ??
            MediaQuery.maybePlatformBrightnessOf(context) ??
            Brightness.light) ==
        Brightness.dark;
    final colors = dark ? PluginsColors.darkColors : PluginsColors.light;
    final s = PluginsStrings.forLocale(locale);
    return PluginsTheme(
      colors: colors,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 13,
          color: colors.fg,
          decoration: TextDecoration.none,
        ),
        child: _Scope(
          controller: controller,
          strings: s,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) {
                  // Read through the scope: the entry is built once, while
                  // the controller and language may change.
                  final scope = _Scope.of(context);
                  return ListenableBuilder(
                    listenable: scope.controller,
                    builder: (context, _) =>
                        _Layout(controller: scope.controller, s: scope.strings),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Scope extends InheritedWidget {
  const _Scope({
    required this.controller,
    required this.strings,
    required super.child,
  });

  final PluginsController controller;
  final PluginsStrings strings;

  static _Scope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Scope>()!;

  @override
  bool updateShouldNotify(_Scope old) =>
      old.controller != controller || old.strings != strings;
}

class _Layout extends StatelessWidget {
  const _Layout({required this.controller, required this.s});

  final PluginsController controller;
  final PluginsStrings s;

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    final selected = controller.selected;
    final consent = controller.consent;
    return Stack(
      children: [
        const Positioned.fill(child: Wallpaper()),
        Positioned(
          top: 0,
          bottom: 0,
          left: 276,
          right: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.pane,
              border: Border(left: BorderSide(color: c.sep, width: .5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 30,
                  offset: Offset(-8, 0),
                ),
              ],
            ),
            child: selected == null
                ? const SizedBox.expand()
                : _Details(
                    key: ValueKey(selected.id),
                    controller: controller,
                    entry: selected,
                    s: s,
                  ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          bottom: 8,
          width: 260,
          child: _Sidebar(controller: controller, s: s),
        ),
        if (consent != null)
          Positioned.fill(
            child: _ConsentSheet(
              controller: controller,
              request: consent,
              s: s,
            ),
          ),
      ],
    );
  }
}

String _name(PluginsStrings s, PluginEntry e) =>
    s.ownPlugin(e.id)?.name ?? e.manifest.name;

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.controller, required this.s});

  final PluginsController controller;
  final PluginsStrings s;

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    final groups = controller.groups((e) => _name(s, e));
    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.fg2,
          ),
        ),
      ),
    );
    return Semantics(
      label: s.pluginList,
      container: true,
      child: Glass(
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room for the window buttons.
            const SizedBox(height: 44),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: MgTextField(
                key: const ValueKey('search'),
                value: controller.query,
                placeholder: s.search,
                semanticLabel: s.searchPlugins,
                leading: SearchGlyph(color: c.fg2),
                onChanged: (v) => controller.query = v,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                children: [
                  if (groups.installed.isNotEmpty) ...[
                    title(s.installedGroup),
                    for (final e in groups.installed) _item(context, e),
                  ],
                  if (groups.available.isNotEmpty) ...[
                    title(s.availableGroup),
                    for (final e in groups.available) _item(context, e),
                  ],
                  if (groups.installed.isEmpty && groups.available.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        s.noResults,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.fg2),
                      ),
                    ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.sep, width: .5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: MgButton(
                  label: s.installFromFile,
                  expand: true,
                  onTap: controller.delegate == null
                      ? null
                      : controller.installFromFile,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, PluginEntry e) {
    final c = PluginsColors.of(context);
    final on = controller.selected?.id == e.id;
    final name = _name(s, e);
    final state = e.installed && !e.active ? s.off : '';
    return Pressable(
      key: ValueKey('item:${e.id}'),
      onTap: () => controller.select(e.id),
      label: name,
      hover: on ? null : c.hover,
      child: Semantics(
        selected: on,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: on ? c.accent : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              PluginIcon(glyph: e.glyphOr(name), color: e.iconColor, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: on ? const Color(0xFFFFFFFF) : c.fg),
                ),
              ),
              if (state.isNotEmpty)
                Text(
                  state,
                  style: TextStyle(
                    fontSize: 12,
                    color: on ? const Color(0xCCFFFFFF) : c.fg2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    super.key,
    required this.controller,
    required this.entry,
    required this.s,
  });

  final PluginsController controller;
  final PluginEntry entry;
  final PluginsStrings s;

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    final m = entry.manifest;
    final own = s.ownPlugin(entry.id);
    final name = own?.name ?? m.name;
    final access = s.accessRows(m.permissions, hooks: m.hooks);
    final update = entry.update;
    final author = [if (m.author != null) m.author!, m.version].join(' · ');

    return Semantics(
      label: name,
      container: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 60),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _gap([
                  Row(
                    children: [
                      PluginIcon(
                        glyph: entry.glyphOr(name),
                        color: entry.iconColor,
                        size: 52,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              entry.builtIn
                                  ? '${s.builtIn} · ${m.version}'
                                  : author,
                              style: TextStyle(color: c.fg2),
                            ),
                          ],
                        ),
                      ),
                      if (entry.installed)
                        MgSwitch(
                          value: entry.active,
                          label: s.enablePlugin,
                          onChanged: (v) => controller.setEnabled(entry.id, v),
                        )
                      else
                        MgButton(
                          label: s.install,
                          primary: true,
                          onTap: () => controller.requestInstall(entry.id),
                        ),
                    ],
                  ),
                  if (entry.disabledReason != null)
                    _Banner(
                      text: s.disabled(entry.disabledReason!),
                      color: PluginsColors.danger,
                    ),
                  if (update != null && entry.installed)
                    _Banner(
                      text: s.updateAvailable(update.manifest.version),
                      color: c.accent,
                      action: MgButton(
                        label: s.review,
                        onTap: () => controller.requestUpdate(entry.id),
                      ),
                    ),
                  if ((own?.description ?? m.description) != null)
                    Text(
                      own?.description ?? m.description!,
                      style: const TextStyle(height: 1.5),
                    ),
                  _section(
                    s.access,
                    Group(
                      children: access.isEmpty
                          ? [Text(s.noAccess, style: TextStyle(color: c.fg2))]
                          : [for (final r in access) _AccessLine(r)],
                    ),
                  ),
                  if (entry.installed && m.settings.isNotEmpty)
                    _section(
                      s.options,
                      Group(
                        children: [
                          for (final setting in m.settings)
                            _SettingLine(
                              controller: controller,
                              entry: entry,
                              setting: setting,
                              labels: own?.labels ?? const {},
                            ),
                        ],
                      ),
                    ),
                  if (m.commands.isNotEmpty)
                    _section(
                      s.commands,
                      Group(
                        children: [
                          for (final k in m.commands)
                            Row(
                              children: [
                                SizedBox(
                                  width: 130,
                                  child: Text(k.name, style: _mono(13)),
                                ),
                                Expanded(
                                  child: Text(
                                    k.title,
                                    style: TextStyle(color: c.fg2),
                                  ),
                                ),
                                if (k.shortcut != null)
                                  Text(
                                    k.shortcut!,
                                    style: _mono(11.5, color: c.fg2),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  _manifest(c),
                  if (entry.installed && !entry.builtIn)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.updatedAt == null
                                ? ''
                                : s.updated(
                                    s.ago(entry.updatedAt!, DateTime.now()),
                                  ),
                            style: TextStyle(fontSize: 12, color: c.fg2),
                          ),
                        ),
                        MgButton(
                          label: s.uninstall,
                          danger: true,
                          onTap: () => controller.uninstall(entry.id),
                        ),
                      ],
                    ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _manifest(PluginsColors c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          expanded: controller.manifestOpen,
          child: Pressable(
            onTap: controller.toggleManifest,
            label: s.manifest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Disclosure(open: controller.manifestOpen, color: c.fg2),
                  const SizedBox(width: 4),
                  Text(
                    s.manifest,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.fg2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (controller.manifestOpen)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.code,
            borderRadius: BorderRadius.circular(10),
          ),
          child: _ManifestText(
            text: entry.manifestSource,
            style: _mono(11.5).copyWith(height: 1.6),
          ),
        ),
    ],
  );

  static Widget _section(String caption, Widget body) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [Caption(caption), body],
  );

  static List<Widget> _gap(List<Widget> children) => [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) const SizedBox(height: 22),
      children[i],
    ],
  ];
}

TextStyle _mono(double size, {Color? color}) => TextStyle(
  fontFamily: monoFamily,
  fontFamilyFallback: monoFallback,
  fontSize: size,
  color: color,
);

/// The manifest as written, in a monospaced font.
class _ManifestText extends StatelessWidget {
  const _ManifestText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text(text, style: style);
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, this.action});

  final String text;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(child: Text(text)),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    ),
  );
}

class _AccessLine extends StatelessWidget {
  const _AccessLine(this.row);

  final AccessRow row;

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    return MergeSemantics(
      child: Row(
        children: [
          AccessIconView(row.icon, color: c.fg2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title),
                const SizedBox(height: 1),
                Text(row.detail, style: TextStyle(fontSize: 12, color: c.fg2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingLine extends StatelessWidget {
  const _SettingLine({
    required this.controller,
    required this.entry,
    required this.setting,
    required this.labels,
  });

  final PluginsController controller;
  final PluginEntry entry;
  final PluginSetting setting;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    final label = labels[setting.key] ?? setting.label;
    final value = entry.setting(setting.key);
    void set(Object? v) => controller.setSetting(entry.id, setting.key, v);
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        switch (setting.type) {
          SettingType.toggle => MgSwitch(
            value: value == true,
            label: label,
            onChanged: set,
          ),
          SettingType.select => MgSelect(
            value: value as String?,
            label: label,
            options: [
              for (final o in setting.options)
                (
                  value: o.value,
                  label: labels['${setting.key}.${o.value}'] ?? o.label,
                ),
            ],
            onChanged: set,
          ),
          SettingType.text => SizedBox(
            width: 220,
            child: MgTextField(
              key: ValueKey('setting:${setting.key}'),
              value: (value as String?) ?? '',
              semanticLabel: label,
              commitOnly: true,
              onChanged: set,
            ),
          ),
        },
      ],
    );
  }
}

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet({
    required this.controller,
    required this.request,
    required this.s,
  });

  final PluginsController controller;
  final ConsentRequest request;
  final PluginsStrings s;

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    final e = request.entry;
    final name = _name(s, e);
    final rows = s.accessRows(request.permissions);
    final update = request.update;
    final warn = rows.any((r) => r.warning);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape):
            controller.cancelConsent,
      },
      child: FocusScope(
        autofocus: true,
        child: ColoredBox(
          color: const Color(0x14000000),
          child: Center(
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: update == null
                  ? s.installTitle(name)
                  : s.updateTitle(name, update.manifest.version),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: c.sep, spreadRadius: .5),
                    BoxShadow(
                      color: c.dark
                          ? const Color(0x8C000000)
                          : const Color(0x2E000000),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        PluginIcon(
                          glyph: e.glyphOr(name),
                          color: e.iconColor,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                update == null
                                    ? s.installTitle(name)
                                    : s.updateTitle(
                                        name,
                                        update.manifest.version,
                                      ),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (e.manifest.author != null)
                                Text(
                                  e.manifest.author!,
                                  style: TextStyle(color: c.fg2),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Caption(update == null ? s.canAccess : s.newAccess),
                    Container(
                      decoration: BoxDecoration(
                        color: c.pane,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        children: [
                          for (final r in rows)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: _AccessLine(r),
                            ),
                        ],
                      ),
                    ),
                    if (warn) ...[
                      const SizedBox(height: 12),
                      _Banner(
                        text: s.allMessagesWarning(
                          e.manifest.author ?? e.manifest.id,
                        ),
                        color: PluginsColors.warning,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        MgButton(
                          label: s.cancel,
                          onTap: controller.cancelConsent,
                        ),
                        const SizedBox(width: 8),
                        MgButton(
                          label: update == null ? s.install : s.update,
                          primary: true,
                          onTap: controller.allowConsent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
