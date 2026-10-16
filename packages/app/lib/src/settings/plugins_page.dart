import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:plugin_host/plugin_host.dart';

import '../plugins/app_plugins.dart';
import 'settings_style.dart';
import 'settings_window.dart';

/// The plugins of this app, as the settings page shows and changes them.
final pluginsControllerProvider = FutureProvider<PluginsController>(
  (ref) async => (await ref.watch(appPluginsProvider.future)).controller,
);

PluginsStrings _strings(BuildContext context) =>
    PluginsStrings.forLocale(Localizations.localeOf(context).languageCode);

String _name(PluginsStrings s, PluginEntry e) =>
    s.ownPlugin(e.id)?.name ?? e.manifest.name;

/// "Built-in plugin · 1.0.0" or "graphy · 0.6.1".
String _byline(PluginsStrings s, PluginEntry e) => [
  if (e.builtIn) s.builtIn else ?e.manifest.author,
  e.manifest.version,
].join(' · ');

/// The Plugins page: installed plugins, ones picked but not installed, and
/// installing from a file. A row opens the plugin's own page.
class PluginsPage extends ConsumerWidget {
  const PluginsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(pluginsControllerProvider).value;
    if (controller == null) {
      return const Center(child: SettingsSpinner(size: 18));
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _list(context, controller),
    );
  }

  Widget _list(BuildContext context, PluginsController controller) {
    final s = _strings(context);
    final groups = controller.groups((e) => _name(s, e));
    final failure = controller.installFailure;
    Widget row(PluginEntry e) => _PluginRow(
      key: ValueKey('plugin:${e.id}'),
      entry: e,
      onTap: () => SettingsNavigation.of(context).push(
        _name(s, e),
        (context) => PluginDetailsPage(controller: controller, id: e.id),
      ),
    );
    return SettingsPage(
      children: [
        if (groups.installed.isNotEmpty)
          SettingsGroup(
            title: s.installedGroup,
            children: [for (final e in groups.installed) row(e)],
          ),
        if (groups.available.isNotEmpty)
          SettingsGroup(
            title: s.availableGroup,
            children: [for (final e in groups.available) row(e)],
          ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: SettingsButton(
            key: const ValueKey('installFromFile'),
            label: s.installFromFile,
            onPressed: () => unawaited(_installFromFile(context, controller)),
          ),
        ),
        if (failure != null)
          SettingsFooter(s.installFailed(failure), error: true),
      ],
    );
  }

  static Future<void> _installFromFile(
    BuildContext context,
    PluginsController controller,
  ) async {
    if (controller.installFailure != null) controller.dismissInstallFailure();
    await controller.installFromFile();
    if (context.mounted) await askConsent(context, controller);
  }
}

class _PluginRow extends StatelessWidget implements SettingsGroupRow {
  const _PluginRow({super.key, required this.entry, required this.onTap});

  final PluginEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = _strings(context);
    final name = _name(s, entry);
    return SettingsRow(
      leading: PluginIcon(
        glyph: entry.glyphOr(name),
        color: entry.iconColor,
        size: 24,
      ),
      title: name,
      subtitle: _byline(s, entry),
      trailing: entry.installed && !entry.active
          ? Text(s.off, style: mgTextStyle(c, color: c.fg2))
          : null,
      chevron: true,
      onTap: onTap,
    );
  }
}

/// One plugin: on or off, what it can reach, its options, commands and
/// manifest, and uninstalling.
class PluginDetailsPage extends StatelessWidget {
  const PluginDetailsPage({
    super.key,
    required this.controller,
    required this.id,
  });

  final PluginsController controller;
  final String id;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final entry = controller.entry(id);
      // Uninstalled while open: nothing left to show.
      if (entry == null) return const SizedBox.expand();
      return _details(context, entry);
    },
  );

  Widget _details(BuildContext context, PluginEntry entry) {
    final c = MgColors.of(context);
    final s = _strings(context);
    final m = entry.manifest;
    final own = s.ownPlugin(entry.id);
    final name = own?.name ?? m.name;
    final description = own?.description ?? m.description;
    final access = s.accessRows(m.permissions, hooks: m.hooks);
    final update = entry.update;
    return SettingsPage(
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            PluginIcon(
              glyph: entry.glyphOr(name),
              color: entry.iconColor,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      name,
                      style: mgTextStyle(
                        c,
                        size: MgType.body + 3,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(_byline(s, entry), style: mgTextStyle(c, color: c.fg2)),
                ],
              ),
            ),
            if (entry.installed)
              SettingsSwitch(
                key: const ValueKey('enabled'),
                value: entry.active,
                label: s.enablePlugin,
                onChanged: (v) => unawaited(controller.setEnabled(entry.id, v)),
              )
            else
              _DefaultButton(
                key: const ValueKey('install'),
                label: s.install,
                onPressed: () {
                  controller.requestInstall(entry.id);
                  unawaited(askConsent(context, controller));
                },
              ),
          ],
        ),
        if (entry.disabledReason != null)
          SettingsFooter(s.disabled(entry.disabledReason!), error: true),
        if (description != null) ...[
          const SizedBox(height: 14),
          Text(description, style: mgTextStyle(c, height: 1.45)),
        ],
        if (update != null && entry.installed)
          SettingsGroup(
            children: [
              SettingsRow(
                title: s.updateAvailable(update.manifest.version),
                trailing: SettingsButton(
                  key: const ValueKey('review'),
                  label: s.review,
                  onPressed: () {
                    controller.requestUpdate(entry.id);
                    unawaited(askConsent(context, controller));
                  },
                ),
              ),
            ],
          ),
        SettingsGroup(
          title: s.access,
          children: access.isEmpty
              ? [SettingsRow(title: s.noAccess)]
              : [for (final r in access) _AccessRowView(r)],
        ),
        if (entry.installed && m.settings.isNotEmpty)
          _Options(controller: controller, entry: entry, own: own),
        if (m.commands.isNotEmpty)
          SettingsGroup(
            title: s.commands,
            children: [
              for (final k in m.commands)
                SettingsRow(
                  title: k.name,
                  subtitle: k.title,
                  trailing: k.shortcut == null
                      ? null
                      : Text(k.shortcut!, style: mgTextStyle(c, color: c.fg2)),
                ),
            ],
          ),
        _Manifest(controller: controller, entry: entry),
        if (entry.installed)
          SettingsGroup(
            children: [
              SettingsRow(
                key: const ValueKey('log'),
                title: s.log,
                chevron: true,
                onTap: () =>
                    SettingsNavigation.of(context)
                        .push(s.log, (context) => PluginLogPage(id: entry.id)),
              ),
            ],
          ),
        if (entry.installed && !entry.builtIn) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.updatedAt == null
                      ? ''
                      : s.updated(s.ago(entry.updatedAt!, DateTime.now())),
                  style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
                ),
              ),
              SettingsButton(
                key: const ValueKey('uninstall'),
                label: s.uninstall,
                destructive: true,
                onPressed: () => unawaited(_uninstall(context, entry, name)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _uninstall(
    BuildContext context,
    PluginEntry entry,
    String name,
  ) async {
    final s = _strings(context);
    final confirmed = await showMgConfirm(
      context,
      title: s.uninstallTitle(name),
      message: s.uninstallMessage,
      confirmLabel: s.uninstallConfirm,
      cancelLabel: s.cancel,
      destructive: true,
    );
    if (confirmed == null) return;
    await controller.uninstall(entry.id);
  }
}

class _AccessRowView extends StatelessWidget implements SettingsGroupRow {
  const _AccessRowView(this.row);

  final AccessRow row;

  @override
  Widget build(BuildContext context) => SettingsRow(
    leading: AccessIconView(row.icon, color: MgColors.of(context).fg2),
    title: row.title,
    subtitle: row.detail,
  );
}

class _Options extends StatelessWidget implements SettingsGroupRow {
  const _Options({
    required this.controller,
    required this.entry,
    required this.own,
  });

  final PluginsController controller;
  final PluginEntry entry;
  final PluginTexts? own;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = _strings(context);
    final labels = own?.labels ?? const <String, String>{};
    return PluginsTheme(
      // The select menu and the text field are the plugins screen's own.
      colors: c.isDark ? PluginsColors.darkColors : PluginsColors.light,
      child: SettingsGroup(
        title: s.options,
        children: [
          for (final setting in entry.manifest.settings)
            _option(setting, labels[setting.key] ?? setting.label, labels),
        ],
      ),
    );
  }

  Widget _option(
    PluginSetting setting,
    String label,
    Map<String, String> labels,
  ) {
    final value = entry.setting(setting.key);
    void set(Object? v) =>
        unawaited(controller.setSetting(entry.id, setting.key, v));
    return switch (setting.type) {
      SettingType.toggle => SettingsSwitchRow(
        key: ValueKey('setting:${setting.key}'),
        title: label,
        value: value == true,
        onChanged: set,
      ),
      SettingType.select => SettingsRow(
        key: ValueKey('setting:${setting.key}'),
        title: label,
        trailing: MgSelect(
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
      ),
      SettingType.text => SettingsRow(
        title: label,
        trailing: SizedBox(
          width: 200,
          child: MgTextField(
            key: ValueKey('setting:${setting.key}'),
            value: (value as String?) ?? '',
            semanticLabel: label,
            commitOnly: true,
            onChanged: set,
          ),
        ),
      ),
    };
  }
}

/// What a plugin logged in this run of the app, its last 200 lines, and
/// why the host turned it off, if it did.
class PluginLogPage extends ConsumerWidget {
  const PluginLogPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = ref.watch(appPluginsProvider).value;
    if (plugins == null) return const SizedBox.expand();
    final c = MgColors.of(context);
    final s = _strings(context);
    return ValueListenableBuilder(
      valueListenable: plugins.logRevision,
      builder: (context, _, _) {
        final lines = plugins.logsOf(id);
        return SettingsPage(
          children: [
            if (lines.isEmpty)
              SettingsFooter(s.logEmpty)
            else ...[
              SettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: SelectableText(
                      lines.join('\n'),
                      style: TextStyle(
                        fontFamily: monoFamily,
                        fontFamilyFallback: monoFallback,
                        fontSize: MgType.caption,
                        height: 1.55,
                        color: c.fg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: SettingsButton(
                  key: const ValueKey('copyLog'),
                  label: s.copyLog,
                  onPressed: () => unawaited(
                    Clipboard.setData(ClipboardData(text: lines.join('\n'))),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The manifest as written, folded away until asked for.
class _Manifest extends StatelessWidget {
  const _Manifest({required this.controller, required this.entry});

  final PluginsController controller;
  final PluginEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = _strings(context);
    final open = controller.manifestOpen;
    return SettingsGroup(
      children: [
        Semantics(
          expanded: open,
          child: SettingsRow(
            key: const ValueKey('manifest'),
            title: s.manifest,
            onTap: controller.toggleManifest,
            trailing: AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: settingsMotionOf(context),
              child: MgIcon(
                MgIcons.chevron,
                size: 13,
                stroke: 2.2,
                color: c.fg2,
              ),
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: SelectableText(
              entry.manifestSource,
              style: TextStyle(
                fontFamily: monoFamily,
                fontFamilyFallback: monoFallback,
                fontSize: MgType.caption,
                height: 1.55,
                color: c.fg,
              ),
            ),
          ),
      ],
    );
  }
}

/// Shows the consent sheet for the controller's pending request, if any,
/// and passes the answer on.
Future<void> askConsent(
  BuildContext context,
  PluginsController controller,
) async {
  final request = controller.consent;
  if (request == null) return;
  final allowed = await showMgSheet<bool>(
    context,
    ConsentSheet(request),
    barrierColor: const Color(0x14000000),
  );
  if (allowed == true) {
    await controller.allowConsent();
  } else {
    controller.cancelConsent();
  }
}

/// "Install “Chat statistics”?": everything the plugin asks for, or for an
/// update what the new version adds, with a warning for all messages.
class ConsentSheet extends StatelessWidget {
  const ConsentSheet(this.request, {super.key});

  final ConsentRequest request;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final g = SettingsColors.of(context);
    final s = _strings(context);
    final e = request.entry;
    final name = _name(s, e);
    final update = request.update;
    // For an update, only the hooks it adds; render.code hands the plugin
    // message text, so it is disclosed too.
    final hooks = [
      for (final h in update?.manifest.hooks ?? e.manifest.hooks)
        if (update == null || !e.manifest.hooks.contains(h)) h,
    ];
    final rows = s.accessRows(request.permissions, hooks: hooks);
    final title = update == null
        ? s.installTitle(name)
        : s.updateTitle(name, update.manifest.version);
    final warn = rows.any((r) => r.warning);
    void allow() => Navigator.of(context).pop(true);
    return CallbackShortcuts(
      // Reading all messages is not something to allow by pressing Return.
      bindings: warn
          ? const {}
          : {
              const SingleActivator(LogicalKeyboardKey.enter): allow,
              const SingleActivator(LogicalKeyboardKey.numpadEnter): allow,
            },
      child: Focus(
        autofocus: true,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: SizedBox(
            width: 380,
            child: Glass(
              radius: MgRadius.popover,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      PluginIcon(
                        glyph: e.glyphOr(name),
                        color: e.iconColor,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: mgTextStyle(c, weight: FontWeight.w600),
                            ),
                            if (e.manifest.author != null)
                              Text(
                                e.manifest.author!,
                                style: mgTextStyle(c, color: c.fg2),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    update == null ? s.canAccess : s.newAccess,
                    style: mgTextStyle(
                      c,
                      size: MgType.caption,
                      weight: FontWeight.w600,
                      color: c.fg2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: g.group,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: g.groupBorder, width: 0.5),
                    ),
                    child: Column(
                      children: [for (final r in rows) _AccessRowView(r)],
                    ),
                  ),
                  if (warn) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s.allMessagesWarning(e.manifest.author ?? e.id),
                        style: mgTextStyle(c, height: 1.35),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SettingsButton(
                        key: const ValueKey('consent.cancel'),
                        label: s.cancel,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: 8),
                      _DefaultButton(
                        key: const ValueKey('consent.allow'),
                        label: update == null ? s.install : s.update,
                        onPressed: allow,
                      ),
                    ],
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

/// The sheet's default button: filled with the accent, answers Return.
class _DefaultButton extends StatelessWidget {
  const _DefaultButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(MgRadius.control),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: mgTextStyle(
                  c,
                  color: c.onAccent,
                  weight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
