import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../sessions_page.dart';
import '../settings_style.dart';
import '../settings_window.dart';
import 'account_ttl_page.dart';
import 'blocked_page.dart';
import 'passcode.dart';
import 'passcode_page.dart';
import 'privacy_providers.dart';
import 'privacy_rule_page.dart';
import 'two_step_page.dart';

/// The settings the Privacy and security page lists, in order.
const privacyPageRules = [
  PrivacyRule.phoneNumber,
  PrivacyRule.lastSeen,
  PrivacyRule.profilePhoto,
  PrivacyRule.forwards,
  PrivacyRule.calls,
  PrivacyRule.voiceMessages,
  PrivacyRule.invites,
  PrivacyRule.bio,
  PrivacyRule.birthday,
];

extension PrivacyRuleLabels on PrivacyRule {
  String title(AppLocalizations l10n) => switch (this) {
    PrivacyRule.phoneNumber => l10n.privacyPhoneNumber,
    PrivacyRule.findByPhoneNumber => l10n.privacyFindByPhone,
    PrivacyRule.lastSeen => l10n.privacyLastSeen,
    PrivacyRule.profilePhoto => l10n.privacyProfilePhotos,
    PrivacyRule.forwards => l10n.privacyForwards,
    PrivacyRule.calls => l10n.privacyCalls,
    PrivacyRule.voiceMessages => l10n.privacyVoiceMessages,
    PrivacyRule.invites => l10n.privacyInvites,
    PrivacyRule.bio => l10n.privacyBio,
    PrivacyRule.birthday => l10n.privacyBirthday,
  };

  /// The question over the audience choice.
  String question(AppLocalizations l10n) => switch (this) {
    PrivacyRule.phoneNumber => l10n.privacyPhoneNumberQuestion,
    PrivacyRule.findByPhoneNumber => l10n.privacyFindByPhoneQuestion,
    PrivacyRule.lastSeen => l10n.privacyLastSeenQuestion,
    PrivacyRule.profilePhoto => l10n.privacyProfilePhotosQuestion,
    PrivacyRule.forwards => l10n.privacyForwardsQuestion,
    PrivacyRule.calls => l10n.privacyCallsQuestion,
    PrivacyRule.voiceMessages => l10n.privacyVoiceMessagesQuestion,
    PrivacyRule.invites => l10n.privacyInvitesQuestion,
    PrivacyRule.bio => l10n.privacyBioQuestion,
    PrivacyRule.birthday => l10n.privacyBirthdayQuestion,
  };

  /// What the setting does, under the choice; empty when it says itself.
  String about(AppLocalizations l10n) => switch (this) {
    PrivacyRule.phoneNumber => l10n.privacyPhoneNumberAbout,
    PrivacyRule.findByPhoneNumber => l10n.privacyFindByPhoneAbout,
    PrivacyRule.lastSeen => l10n.privacyLastSeenAbout,
    PrivacyRule.forwards => l10n.privacyForwardsAbout,
    PrivacyRule.voiceMessages => l10n.privacyVoiceMessagesAbout,
    _ => '',
  };
}

String audienceLabel(AppLocalizations l10n, PrivacyAudience audience) =>
    switch (audience) {
      PrivacyAudience.everybody => l10n.privacyEverybody,
      PrivacyAudience.contacts => l10n.privacyMyContacts,
      PrivacyAudience.nobody => l10n.privacyNobody,
    };

/// "My contacts (−2, +1)", as TelegramSwift shows a setting with
/// exceptions.
String privacySummary(AppLocalizations l10n, PrivacyChoice choice) {
  final counts = [
    if (choice.neverCount > 0) '−${choice.neverCount}',
    if (choice.alwaysCount > 0) '+${choice.alwaysCount}',
  ];
  final audience = audienceLabel(l10n, choice.audience);
  return counts.isEmpty ? audience : '$audience (${counts.join(', ')})';
}

/// Privacy and security, after TelegramSwift's PrivacyAndSecurity page:
/// the blocked list and the signed-in devices, then who can see and do
/// what.
class PrivacySecurityPage extends ConsumerWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final navigation = SettingsNavigation.of(context);
    final choices = ref.watch(privacyChoicesProvider);
    final blocked = ref.watch(blockedCountProvider).value;
    final sessions = ref.watch(activeSessionsProvider).value;
    final passcode = ref.watch(passcodeLockProvider).settings.enabled;
    final twoStep = ref.watch(twoStepProvider).value?.hasPassword;
    final ttl = ref.watch(accountTtlProvider).value;
    String onOff(bool on) => on ? l10n.twoStepOn : l10n.twoStepOff;
    Widget? value(String? text) =>
        text == null ? null : Text(text, style: mgTextStyle(c, color: c.fg2));

    return SettingsPage(
      children: [
        SettingsGroup(
          children: [
            SettingsRow(
              key: const ValueKey('blockedUsers'),
              leading: const SettingsSymbol(
                icon: blockedIcon,
                tint: Color(0xFFFF3B30),
              ),
              title: l10n.blockedUsers,
              trailing: value(
                blocked == null || blocked == 0 ? null : '$blocked',
              ),
              chevron: true,
              onTap: () => navigation.push(
                l10n.blockedUsers,
                (context) => const BlockedUsersPage(),
              ),
            ),
            SettingsRow(
              key: const ValueKey('passcode'),
              leading: const SettingsSymbol(
                icon: MgIcons.lock,
                tint: Color(0xFF0A7CFF),
              ),
              title: l10n.passcodeLock,
              trailing: value(onOff(passcode)),
              chevron: true,
              onTap: () => navigation.push(
                l10n.passcodeLock,
                (context) => const PasscodePage(),
              ),
            ),
            SettingsRow(
              key: const ValueKey('twoStep'),
              leading: const SettingsSymbol(
                icon: _keyIcon,
                tint: Color(0xFFFF9500),
              ),
              title: l10n.twoStep,
              trailing: value(twoStep == null ? null : onOff(twoStep)),
              chevron: true,
              onTap: () => navigation.push(
                l10n.twoStep,
                (context) => const TwoStepPage(),
              ),
            ),
            SettingsRow(
              key: const ValueKey('activeSessions'),
              leading: const SettingsSymbol(
                icon: _devicesIcon,
                tint: Color(0xFF34A853),
              ),
              title: l10n.activeSessions,
              trailing: value(sessions == null ? null : '${sessions.length}'),
              chevron: true,
              onTap: () => navigation.push(
                l10n.activeSessions,
                (context) => const ActiveSessionsPage(),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l10n.privacyTitle,
          // A setting that failed to load says so on its row.
          footer:
              (choices.hasError && !choices.hasValue) ||
                  (choices.value?.length ?? PrivacyRule.values.length) <
                      PrivacyRule.values.length
              ? SettingsFooter(l10n.privacyLoadFailed, error: true)
              : null,
          children: [
            for (final rule in privacyPageRules)
              SettingsRow(
                key: ValueKey(rule),
                title: rule.title(l10n),
                trailing: switch (choices.value?[rule]) {
                  final choice? => value(privacySummary(l10n, choice)),
                  null when choices.isLoading => const SettingsSpinner(),
                  null => value(l10n.privacyNotLoaded),
                },
                chevron: true,
                onTap: () => navigation.push(
                  rule.title(l10n),
                  (context) => PrivacyRulePage(rule: rule),
                ),
              ),
          ],
        ),
        SettingsGroup(
          title: l10n.accountTtlTitle,
          footer: SettingsFooter(l10n.accountTtlAbout),
          children: [
            SettingsRow(
              key: const ValueKey('accountTtl'),
              title: l10n.accountTtlRow,
              trailing: value(ttl == null ? null : accountTtlLabel(l10n, ttl)),
              chevron: true,
              onTap: () => navigation.push(
                l10n.accountTtlTitle,
                (context) => const AccountTtlPage(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A circle crossed out, for the blocked list.
const blockedIcon = MgIconData(
  'blocked',
  '<circle cx="12" cy="12" r="8.5"/><path d="M6 6l12 12"/>',
);

/// A laptop and a phone, for the sessions row.
const _devicesIcon = MgIconData(
  'devices',
  '<rect x="2.5" y="5" width="13" height="9" rx="1.5"/>'
      '<path d="M1 18h12"/><rect x="16.5" y="9" width="6" height="11" rx="1.5"/>',
);

/// A key, for two-step verification.
const _keyIcon = MgIconData(
  'key',
  '<circle cx="8" cy="15" r="4.5"/><path d="M11.2 11.8L20 3M16.5 6.5l2.5 2.5'
      'M14 9l2 2"/>',
);
