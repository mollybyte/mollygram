import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'preferences.dart';
import 'selection_check.dart';
import 'settings_style.dart';
import 'settings_window.dart';

/// The "Language" entry of the settings source list.
final languageSection = SettingsSection(
  id: 'language',
  icon: MgIcons.translate,
  tint: const Color(0xFFFF9500),
  title: (l10n) => l10n.language,
  keywords: (l10n) => ['English', 'Русский'],
  builder: (context) => const LanguagePage(),
);

/// The app's language: the system's, English or Russian. It applies at
/// once; TDLib's language packs are left alone, so chats keep theirs.
class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  /// Each language in its own name, as macOS lists them.
  static String nameOf(AppLocalizations l10n, AppLanguage language) =>
      switch (language) {
        AppLanguage.system => l10n.languageSystem,
        AppLanguage.english => 'English',
        AppLanguage.russian => 'Русский',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(preferencesProvider.select((p) => p.language));
    return SettingsPage(
      children: [
        SettingsGroup(
          title: l10n.language,
          footer: SettingsFooter(l10n.languageHint),
          children: [
            for (final language in AppLanguage.values)
              Semantics(
                selected: language == current,
                child: SettingsRow(
                  key: ValueKey(('language', language.name)),
                  title: nameOf(l10n, language),
                  onTap: language == current
                      ? null
                      : () => ref
                            .read(preferencesProvider.notifier)
                            .update((p) => p.copyWith(language: language)),
                  trailing: SelectionCheck(checked: language == current),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
