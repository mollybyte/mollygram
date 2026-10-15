import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../l10n/app_localizations.dart';
import 'auth/sign_in_screen.dart';
import 'home/home_screen.dart';
import 'home/workspace_storage.dart';
import 'session/close_before_exit.dart';
import 'session/providers.dart';
import 'settings/appearance.dart';
import 'settings/preferences.dart';
import 'settings/privacy/passcode_lock_screen.dart';

class MollygramApp extends ConsumerWidget {
  const MollygramApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final themes = appThemes(preferences);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: preferences.theme,
      // A theme or accent change cross-fades.
      themeAnimationDuration: themeAnimationDuration(preferences.reduceMotion),
      themeAnimationCurve: Curves.easeOut,
      builder: (context, child) => ReduceMotionScope(child: child!),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _CloseSessionBeforeExit(
        child: Material(
          type: MaterialType.transparency,
          child: PasscodeGate(child: _Root()),
        ),
      ),
    );
  }
}

/// Saves the window layout and closes TDLib before the process exits; see
/// [CloseBeforeExit].
class _CloseSessionBeforeExit extends ConsumerWidget {
  const _CloseSessionBeforeExit({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => CloseBeforeExit(
    close: () async {
      // A layout change still waiting to be saved is written first.
      await ref.read(workspaceSaverProvider).flush();
      await ref.read(preferencesProvider.notifier).flush();
      await ref.read(telegramSessionProvider).value?.dispose();
    },
    child: child,
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
    // Signed out: the saved window layout belonged to that account.
    ref.listen(authorizationStageProvider, (_, next) {
      switch (next.value?.kind) {
        case AuthorizationStageKind.phoneNumber ||
            AuthorizationStageKind.qrCode:
          unawaited(ref.read(workspaceSaverProvider).clear());
        default:
      }
    });
    final stage = ref.watch(authorizationStageProvider).value;
    if (stage == null) return const SignInScreen.starting();
    if (stage.kind == AuthorizationStageKind.ready) return const HomeScreen();
    return SignInScreen(stage: stage);
  }
}
