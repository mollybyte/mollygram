import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../l10n/app_localizations.dart';
import 'auth/sign_in_screen.dart';
import 'home/home_screen.dart';
import 'session/providers.dart';
import 'ui/glass.dart';
import 'ui/theme.dart';

class MollygramApp extends StatelessWidget {
  const MollygramApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(MgColors.light),
    darkTheme: buildTheme(MgColors.darkTheme),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const GlassSettings(
      blur: true,
      child: Material(type: MaterialType.transparency, child: _Root()),
    ),
  );
}

/// Shows sign-in until TDLib reports an authorized account, then the chats.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(telegramSessionProvider);
    return switch (session) {
      AsyncError(error: MissingApiKeys()) => SignInScreen.message(
        title: l10n.missingKeysTitle,
        description: l10n.missingKeysHint,
      ),
      AsyncError(:final error) => SignInScreen.message(
        title: l10n.startFailedTitle,
        description: '$error',
      ),
      AsyncData() => const _Authorized(),
      _ => const SignInScreen.starting(),
    };
  }
}

class _Authorized extends ConsumerWidget {
  const _Authorized();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(authorizationStageProvider).value;
    if (stage == null) return const SignInScreen.starting();
    if (stage.kind == AuthorizationStageKind.ready) return const HomeScreen();
    return SignInScreen(stage: stage);
  }
}
