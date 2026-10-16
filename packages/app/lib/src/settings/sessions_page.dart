import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../avatar/peer_avatar.dart';
import '../home/format.dart';
import '../session/providers.dart';
import 'settings_style.dart';

/// Every session signed in to the account, this one first.
final activeSessionsProvider = FutureProvider.autoDispose<List<ActiveSession>>(
  (ref) =>
      ref.watch(telegramSessionProvider).requireValue.account.activeSessions(),
);

/// The business bot connected to the account; null when there is none.
final connectedBotProvider = FutureProvider.autoDispose<ConnectedBot?>(
  (ref) =>
      ref.watch(telegramSessionProvider).requireValue.account.connectedBot(),
);

/// A laptop and a phone, for the sessions row.
const _devicesIcon = MgIconData(
  'devices',
  '<rect x="2.5" y="5" width="13" height="9" rx="1.5"/>'
      '<path d="M1 18h12"/><rect x="16.5" y="9" width="6" height="11" rx="1.5"/>',
);

/// The devices signed in to the account, after TelegramSwift's
/// RecentSessionsController: this one on top with "Terminate all other
/// sessions", then the others from the most recently active. Clicking a
/// session asks before terminating it.
class ActiveSessionsPage extends ConsumerStatefulWidget {
  const ActiveSessionsPage({super.key});

  @override
  ConsumerState<ActiveSessionsPage> createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends ConsumerState<ActiveSessionsPage> {
  /// Sessions being terminated, hidden right away.
  final _ending = <int>{};
  String? _error;

  AccountSettings get _account =>
      ref.read(telegramSessionProvider).requireValue.account;

  Future<void> _run(Set<int> ids, Future<void> Function() request) async {
    setState(() {
      _ending.addAll(ids);
      _error = null;
    });
    try {
      await request();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ending.removeAll(ids);
        _error = AppLocalizations.of(context).saveFailed;
      });
      return;
    }
    ref.invalidate(activeSessionsProvider);
  }

  Future<void> _terminate(ActiveSession session) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.terminateSessionTitle,
      message: [
        session.application,
        session.device,
      ].where((s) => s.isNotEmpty).join('\n'),
      confirmLabel: l10n.terminate,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted) return;
    await _run({session.id}, () => _account.terminateSession(session.id));
  }

  Future<void> _terminateOthers(List<ActiveSession> others) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.terminateOthersTitle,
      message: l10n.terminateOthersHint,
      confirmLabel: l10n.terminate,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted) return;
    await _run({for (final s in others) s.id}, _account.terminateOtherSessions);
  }

  Future<void> _disconnect(ConnectedBot bot) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.disconnectBotTitle(bot.name),
      message: l10n.connectedBotHint,
      confirmLabel: l10n.disconnect,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted) return;
    try {
      await _account.disconnectBot(bot.userId);
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).saveFailed);
      }
      return;
    }
    ref.invalidate(connectedBotProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(activeSessionsProvider);
    final sessions = state.value;
    if (sessions == null) {
      if (state.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.sessionsFailed, style: mgTextStyle(c, color: c.fg2)),
              const SizedBox(height: 10),
              SettingsButton(
                label: l10n.tryAgain,
                onPressed: () => ref.invalidate(activeSessionsProvider),
              ),
            ],
          ),
        );
      }
      return const Center(child: SettingsSpinner(size: 18));
    }
    final current = sessions.where((s) => s.isCurrent).toList();
    final others = [
      for (final s in sessions)
        if (!s.isCurrent && !_ending.contains(s.id)) s,
    ];
    final botState = ref.watch(connectedBotProvider);
    final bot = botState.value;
    return SettingsPage(
      children: [
        // TDLib asks for the connected bot to be shown with the sessions.
        if (bot != null)
          SettingsGroup(
            key: const ValueKey('connectedBot'),
            title: l10n.connectedBot,
            footer: SettingsFooter(l10n.connectedBotHint),
            children: [
              SettingsRow(
                leading: PeerAvatar(name: bot.name, size: 28, photo: bot.photo),
                title: bot.name,
                subtitle: bot.username.isEmpty ? null : '@${bot.username}',
                trailing: SettingsButton(
                  label: l10n.disconnect,
                  destructive: true,
                  onPressed: () => _disconnect(bot),
                ),
              ),
            ],
          ),
        if (bot == null && botState.hasError)
          SettingsGroup(
            key: const ValueKey('connectedBotFailed'),
            title: l10n.connectedBot,
            children: [
              SettingsRow(
                title: l10n.connectedBotFailed,
                trailing: SettingsButton(
                  label: l10n.tryAgain,
                  onPressed: () => ref.invalidate(connectedBotProvider),
                ),
              ),
            ],
          ),
        if (current.isNotEmpty)
          SettingsGroup(
            title: l10n.thisDevice,
            footer: _error == null
                ? null
                : SettingsFooter(_error!, error: true),
            children: [for (final s in current) _SessionRow(session: s)],
          ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SettingsButton(
              key: const ValueKey('terminateOthers'),
              label: l10n.terminateOthers,
              destructive: true,
              onPressed: () => _terminateOthers(others),
            ),
          ),
        ],
        AnimatedSize(
          duration: settingsMotionOf(context),
          curve: settingsCurve,
          alignment: Alignment.topCenter,
          child: others.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: SettingsFooter(l10n.noOtherSessions),
                )
              : SettingsGroup(
                  title: l10n.otherSessions,
                  children: [
                    for (final s in others)
                      _SessionRow(
                        key: ValueKey(s.id),
                        session: s,
                        onTerminate: () => _terminate(s),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SessionRow extends StatefulWidget implements SettingsGroupRow {
  const _SessionRow({super.key, required this.session, this.onTerminate});

  final ActiveSession session;

  /// Null for this session, which is ended by logging out.
  final VoidCallback? onTerminate;

  @override
  State<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends State<_SessionRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final s = widget.session;
    final when = s.isCurrent
        ? l10n.sessionOnline
        : s.isUnconfirmed
        ? l10n.sessionUnconfirmed
        : formatChatTime(s.lastActiveDate, locale);
    final details = [
      s.device,
      [s.location, when].where((p) => p.isNotEmpty).join(' · '),
    ].where((p) => p.isNotEmpty).join('\n');
    final onTerminate = widget.onTerminate;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SettingsRow(
        leading: SettingsSymbol(
          icon: _devicesIcon,
          tint: s.isCurrent ? c.accent : const Color(0xFF8E8E93),
          size: 28,
        ),
        title: s.application.isEmpty ? s.device : s.application,
        subtitle: details,
        onTap: onTerminate,
        trailing: onTerminate == null
            ? null
            : AnimatedOpacity(
                duration: settingsMotionOf(context),
                opacity: _hover ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_hover,
                  child: SettingsButton(
                    label: l10n.terminate,
                    destructive: true,
                    onPressed: onTerminate,
                  ),
                ),
              ),
      ),
    );
  }
}
