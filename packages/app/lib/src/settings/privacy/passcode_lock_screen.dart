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

/// The session could not start, so there is no account to log out of.
final class NoSessionToLogOut implements Exception {
  const NoSessionToLogOut();
}

/// Logs out for a forgotten passcode, once the session has started.
final passcodeLogOutProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      await ref.read(telegramSessionProvider.future);
    } on Object {
      throw const NoSessionToLogOut();
    }
    await ref.read(logOutProvider)();
  },
);

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
    final keys = HardwareKeyboard.instance;
    // ⌘L only: Ctrl+L is a text editing key on macOS.
    final command =
        keys.isMetaPressed &&
        !keys.isControlPressed &&
        !keys.isShiftPressed &&
        !keys.isAltPressed;
    if (command && event.logicalKey == LogicalKeyboardKey.keyL) {
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
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: locked
                ? const PasscodeLockScreen()
                : const SizedBox.shrink(),
          ),
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

  /// What went wrong last, under the field.
  String? _error;
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
    _scheduleRetry();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _shake.dispose();
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }

  PasscodeLock get _lock => ref.read(passcodeLockProvider.notifier);
  DateTime _clock() => ref.read(passcodeClockProvider)();

  /// While a wait after wrong passcodes runs, the field is off; it comes
  /// back on by itself.
  void _scheduleRetry() {
    _wait?.cancel();
    final retryAt = ref.read(passcodeLockProvider).retryAt;
    if (retryAt == null) return;
    final left = retryAt.difference(_clock());
    if (left <= Duration.zero) return;
    _wait = Timer(left, () {
      if (!mounted) return;
      setState(() => _error = null);
      _focus.requestFocus();
    });
  }

  bool get _waiting {
    final retryAt = ref.read(passcodeLockProvider).retryAt;
    return retryAt != null && _clock().isBefore(retryAt);
  }

  String _waitText(AppLocalizations l10n) {
    final retryAt = ref.read(passcodeLockProvider).retryAt!;
    final seconds = retryAt.difference(_clock()).inSeconds + 1;
    return seconds >= 60
        ? l10n.passcodeWaitMinutes((seconds / 60).ceil())
        : l10n.passcodeWaitSeconds(seconds);
  }

  Future<void> _unlock() async {
    if (_busy || _input.text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    UnlockResult result;
    try {
      result = await _lock.unlock(_input.text);
    } on Object {
      result = UnlockResult.wrong;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || result == UnlockResult.unlocked) return;
    _input.clear();
    _scheduleRetry();
    setState(() => _error = _waiting ? _waitText(l10n) : l10n.passcodeWrong);
    _focus.requestFocus();
    if (!MediaQuery.disableAnimationsOf(context)) {
      unawaited(_shake.forward(from: 0));
    }
  }

  /// The way out when the passcode is forgotten, as in TelegramSwift: log
  /// out, and only once that is done remove the passcode. The window
  /// stays locked meanwhile, and a failed log out leaves the lock as it
  /// was. A session still starting is waited for; one that can't start
  /// leaves the passcode, since removing it alone would open the account
  /// at the next launch.
  Future<void> _forgot() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMgConfirm(
      context,
      title: l10n.passcodeLogOutTitle,
      message: l10n.passcodeLogOutMessage,
      confirmLabel: l10n.logOut,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted) return;
    final lock = _lock;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? failure;
    try {
      await ref.read(passcodeLogOutProvider)();
    } on NoSessionToLogOut {
      failure = l10n.passcodeForgotNoSession;
    } on Object {
      failure = l10n.passcodeLogOutFailed;
    }
    if (failure == null) {
      try {
        await lock.forget();
      } on Object {
        // Logged out already; the passcode stays until the keychain works.
      }
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(passcodeLockProvider);
    final unreadable = state.unreadable;
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
                      unreadable ? l10n.passcodeUnreadable : l10n.passcodeEnter,
                      textAlign: TextAlign.center,
                      style: mgTextStyle(c, color: c.fg2, height: 1.4),
                    ),
                    const SizedBox(height: 22),
                    if (unreadable)
                      Center(
                        child: MgTextButton(
                          label: l10n.passcodeReadAgain,
                          onPressed: () => unawaited(_lock.retryRead()),
                        ),
                      )
                    else
                      AnimatedBuilder(
                        animation: _shake,
                        builder: (context, child) => Transform.translate(
                          // A damped side to side, as the macOS login field.
                          offset: Offset(
                            sin(_shake.value * pi * 6) *
                                10 *
                                (1 - _shake.value),
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
                          enabled: !_busy && !_waiting,
                          errorText: _error,
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: (_) => unawaited(_unlock()),
                        ),
                      ),
                    if (unreadable && _error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: mgTextStyle(
                          c,
                          size: MgType.caption,
                          color: MgDestructive.color,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Center(
                      child: MgTextButton(
                        label: l10n.passcodeForgot,
                        onPressed: _busy ? null : () => unawaited(_forgot()),
                      ),
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
