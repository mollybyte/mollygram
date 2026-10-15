import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../../session/providers.dart';
import '../account_page.dart' show logOutProvider;
import 'passcode.dart';

/// Puts the passcode lock over [child]: nothing shows until the keychain
/// is read, then the lock covers the window while it is locked. Every
/// click and key counts as activity for the auto-lock, and ⌘L locks.
class PasscodeGate extends ConsumerStatefulWidget {
  const PasscodeGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PasscodeGate> createState() => _PasscodeGateState();
}

class _PasscodeGateState extends ConsumerState<PasscodeGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  PasscodeLock get _lock => ref.read(passcodeLockProvider.notifier);

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final meta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (meta && event.logicalKey == LogicalKeyboardKey.keyL) {
      final state = ref.read(passcodeLockProvider);
      if (state.settings.enabled && !state.locked) {
        _lock.lock();
        return true;
      }
    }
    _lock.activity();
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back after being away long enough finds the window locked.
    if (state == AppLifecycleState.resumed) _lock.check();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passcodeLockProvider);
    final c = MgColors.of(context);
    if (!state.loaded) return ColoredBox(color: c.windowBackground);
    final locked = state.locked;
    return Listener(
      onPointerDown: (_) => _lock.activity(),
      onPointerSignal: (_) => _lock.activity(),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: locked,
            child: ExcludeSemantics(
              excluding: locked,
              child: IgnorePointer(ignoring: locked, child: widget.child),
            ),
          ),
          if (locked) const PasscodeLockScreen(),
        ],
      ),
    );
  }
}

/// The lock over the window: the app blurred behind frosted glass, the
/// mark, and the passcode field. Return unlocks; a wrong passcode shakes
/// the field.
class PasscodeLockScreen extends ConsumerStatefulWidget {
  const PasscodeLockScreen({super.key});

  @override
  ConsumerState<PasscodeLockScreen> createState() => _PasscodeLockScreenState();
}

class _PasscodeLockScreenState extends ConsumerState<PasscodeLockScreen>
    with SingleTickerProviderStateMixin {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  var _busy = false;
  var _wrong = false;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _shake.dispose();
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy || _input.text.isEmpty) return;
    setState(() => _busy = true);
    final ok = await ref
        .read(passcodeLockProvider.notifier)
        .unlock(_input.text);
    if (!mounted || ok) return;
    setState(() {
      _busy = false;
      _wrong = true;
    });
    _input.clear();
    _focus.requestFocus();
    if (!MediaQuery.disableAnimationsOf(context)) {
      unawaited(_shake.forward(from: 0));
    }
  }

  /// The way out when the passcode is forgotten, as in TelegramSwift:
  /// log out, which also removes the passcode.
  Future<void> _logOut() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.passcodeLogOutTitle,
      message: l10n.passcodeLogOutMessage,
      confirmLabel: l10n.logOut,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final logOut = ref.read(logOutProvider);
    await ref.read(passcodeLockProvider.notifier).turnOff();
    await logOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(telegramSessionProvider).hasValue;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: ColoredBox(
            color: c.windowBackground.withValues(alpha: c.isDark ? 0.72 : 0.6),
            child: Center(
              child: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppMark(size: 56)),
                    const SizedBox(height: 22),
                    Text(
                      l10n.passcodeLocked,
                      textAlign: TextAlign.center,
                      style: mgTextStyle(
                        c,
                        size: 20,
                        weight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.passcodeEnter,
                      textAlign: TextAlign.center,
                      style: mgTextStyle(c, color: c.fg2, height: 1.4),
                    ),
                    const SizedBox(height: 22),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (context, child) => Transform.translate(
                        // A damped side to side, as the macOS login field.
                        offset: Offset(
                          sin(_shake.value * pi * 6) * 10 * (1 - _shake.value),
                          0,
                        ),
                        child: child,
                      ),
                      child: MgUnderlineField(
                        key: const ValueKey('passcodeField'),
                        controller: _input,
                        focusNode: _focus,
                        hintText: l10n.passcodeHint,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        errorText: _wrong ? l10n.passcodeWrong : null,
                        onChanged: (_) {
                          if (_wrong) setState(() => _wrong = false);
                        },
                        onSubmitted: (_) => unawaited(_unlock()),
                      ),
                    ),
                    if (signedIn) ...[
                      const SizedBox(height: 14),
                      Center(
                        child: MgTextButton(
                          label: l10n.passcodeForgot,
                          onPressed: () => unawaited(_logOut()),
                        ),
                      ),
                    ],
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
