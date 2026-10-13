import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' show TdException;

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import '../ui/glass.dart';
import '../ui/theme.dart';
import '../ui/wallpaper.dart';
import '../ui/widgets.dart';
import 'qr_view.dart';

/// Sign-in on top of the wallpaper: one floating glass card.
///
/// The QR code comes first, as in the official desktop app; the phone number
/// form is one click away.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required AuthorizationStage this.stage})
    : _title = null,
      _description = null;

  /// TDLib is still starting.
  const SignInScreen.starting({super.key})
    : stage = null,
      _title = null,
      _description = null;

  /// A problem that sign-in cannot continue past.
  const SignInScreen.message({
    super.key,
    required String this._title,
    required String this._description,
  }) : stage = null;

  final AuthorizationStage? stage;
  final String? _title;
  final String? _description;

  @override
  Widget build(BuildContext context) {
    final stage = this.stage;
    final title = _title;
    final Widget content;
    if (title != null) {
      content = _Heading(title: title, description: _description!);
    } else if (stage == null) {
      content = const _Starting();
    } else {
      content = _SignInFlow(stage: stage);
    }
    return BackdropGroup(
      child: Stack(
        children: [
          const Positioned.fill(child: Wallpaper()),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 44,
            child: WindowDragArea(),
          ),
          Center(
            child: SizedBox(
              width: 348,
              child: Glass(
                radius: 20,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: DefaultTextStyle.merge(
                  style: mgText(MgColors.of(context)),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Starting extends StatelessWidget {
  const _Starting();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CupertinoActivityIndicator(),
      const SizedBox(height: 12),
      Text(
        AppLocalizations.of(context).starting,
        style: TextStyle(color: MgColors.of(context).fg2),
      ),
    ],
  );
}

class _SignInFlow extends ConsumerStatefulWidget {
  const _SignInFlow({required this.stage});

  final AuthorizationStage stage;

  @override
  ConsumerState<_SignInFlow> createState() => _SignInFlowState();
}

class _SignInFlowState extends ConsumerState<_SignInFlow> {
  /// The user chose the phone number instead of the QR code, or asked to
  /// change the number while TDLib waits for a code.
  bool _wantsPhone = false;
  bool _busy = false;
  String? _error;

  AuthorizationStageKind get _kind => widget.stage.kind;

  @override
  void initState() {
    super.initState();
    _requestQrIfNeeded();
  }

  @override
  void didUpdateWidget(_SignInFlow old) {
    super.didUpdateWidget(old);
    if (old.stage.kind == _kind) return;
    _error = null;
    if (_kind == AuthorizationStageKind.code ||
        _kind == AuthorizationStageKind.password) {
      _wantsPhone = false;
    }
    _requestQrIfNeeded();
  }

  void _requestQrIfNeeded() {
    if (_kind != AuthorizationStageKind.phoneNumber || _wantsPhone) return;
    final actions = ref.read(signInActionsProvider);
    // A failed QR request (no network, an old account type) falls back to
    // the phone number form.
    actions.requestQrCode().catchError((Object error) {
      if (mounted) _fail(error, showPhone: true);
    });
  }

  Future<void> _run(Future<void> Function() request) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await request();
    } catch (error) {
      if (mounted) _fail(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(Object error, {bool showPhone = false}) {
    setState(() {
      _error = _describe(AppLocalizations.of(context), error);
      if (showPhone) _wantsPhone = true;
    });
  }

  void _showQr() {
    setState(() {
      _wantsPhone = false;
      _error = null;
    });
    _requestQrIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = ref.watch(signInActionsProvider);
    final phoneStep =
        _kind == AuthorizationStageKind.phoneNumber ||
        _kind == AuthorizationStageKind.qrCode ||
        _kind == AuthorizationStageKind.code;

    if (_wantsPhone && phoneStep) {
      return _Form(
        key: const ValueKey('phone'),
        title: l10n.phoneTitle,
        description: l10n.phoneHint,
        label: l10n.phoneLabel,
        keyboardType: TextInputType.phone,
        busy: _busy,
        error: _error,
        onSubmit: (value) => _run(() async {
          await actions.submitPhone(value.trim());
          if (mounted) setState(() => _wantsPhone = false);
        }),
        secondary: _kind == AuthorizationStageKind.code
            ? null
            : _LinkButton(l10n.signInWithQr, onTap: _showQr),
      );
    }

    return switch (_kind) {
      AuthorizationStageKind.phoneNumber ||
      AuthorizationStageKind.qrCode => _Qr(
        key: const ValueKey('qr'),
        link: widget.stage.qrLink,
        error: _error,
        onPhone: () => setState(() {
          _wantsPhone = true;
          _error = null;
        }),
      ),
      AuthorizationStageKind.code => _Form(
        key: const ValueKey('code'),
        title: l10n.codeTitle,
        description: l10n.codeHint,
        label: l10n.codeLabel,
        keyboardType: TextInputType.number,
        busy: _busy,
        error: _error,
        onSubmit: (value) => _run(() => actions.submitCode(value.trim())),
        secondary: _LinkButton(
          l10n.wrongNumber,
          onTap: () => setState(() {
            _wantsPhone = true;
            _error = null;
          }),
        ),
      ),
      AuthorizationStageKind.password => _Form(
        key: const ValueKey('password'),
        title: l10n.passwordTitle,
        description: widget.stage.passwordHint.isEmpty
            ? l10n.passwordHint
            : l10n.passwordHintWithHint(widget.stage.passwordHint),
        label: l10n.passwordLabel,
        obscureText: true,
        busy: _busy,
        error: _error,
        onSubmit: (value) => _run(() => actions.submitPassword(value)),
      ),
      AuthorizationStageKind.tdlibParameters ||
      AuthorizationStageKind.ready => const _Starting(),
      AuthorizationStageKind.unavailable => _Heading(
        title: l10n.signInTitle,
        description: l10n.unsupportedStep,
      ),
    };
  }
}

/// Maps TDLib's error codes to text a person can act on.
String _describe(AppLocalizations l10n, Object error) {
  if (error is! TdException) return l10n.errorGeneric('$error');
  final message = error.message;
  if (message.startsWith('PHONE_NUMBER_')) return l10n.errorInvalidPhone;
  if (message == 'PHONE_CODE_EXPIRED') return l10n.errorCodeExpired;
  if (message.startsWith('PHONE_CODE_')) return l10n.errorInvalidCode;
  if (message == 'PASSWORD_HASH_INVALID') return l10n.errorInvalidPassword;
  if (error.code == 429 || message.startsWith('Too Many Requests')) {
    return l10n.errorTooManyAttempts;
  }
  return l10n.errorGeneric(message);
}

class _Qr extends StatelessWidget {
  const _Qr({super.key, required this.link, required this.onPhone, this.error});

  final String? link;
  final VoidCallback onPhone;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final link = this.link;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 196,
          height: 196,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: link == null
              ? Center(
                  child: Text(
                    l10n.signInQrLoading,
                    style: const TextStyle(color: Color(0xFF86868B)),
                  ),
                )
              : QrView(data: link, color: const Color(0xFF1D1D1F)),
        ),
        const SizedBox(height: 20),
        _Heading(
          title: l10n.signInTitle,
          description: l10n.signInQrSteps,
          center: true,
        ),
        if (error != null) ...[const SizedBox(height: 10), _ErrorText(error!)],
        const SizedBox(height: 14),
        _LinkButton(l10n.signInWithPhone, onTap: onPhone),
      ],
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({
    super.key,
    required this.title,
    required this.description,
    required this.label,
    required this.onSubmit,
    required this.busy,
    this.error,
    this.keyboardType,
    this.obscureText = false,
    this.secondary,
  });

  final String title;
  final String description;
  final String label;
  final ValueChanged<String> onSubmit;
  final bool busy;
  final String? error;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? secondary;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.busy || _input.text.trim().isEmpty) return;
    widget.onSubmit(_input.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(title: widget.title, description: widget.description),
        const SizedBox(height: 18),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: c.field,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _input,
            autofocus: true,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            enabled: !widget.busy,
            onSubmitted: (_) => _submit(),
            style: mgText(c, size: 13.5),
            cursorHeight: 16,
            decoration: InputDecoration.collapsed(
              hintText: widget.label,
              hintStyle: mgText(c, size: 13.5).copyWith(color: c.fg2),
            ),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 8),
          _ErrorText(widget.error!),
        ],
        const SizedBox(height: 14),
        _PrimaryButton(
          label: l10n.continueAction,
          busy: widget.busy,
          onTap: _input.text.trim().isEmpty ? null : _submit,
        ),
        if (widget.secondary != null) ...[
          const SizedBox(height: 10),
          Center(child: widget.secondary),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.description,
    this.center = false,
  });

  final String title;
  final String description;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final align = center ? TextAlign.center : TextAlign.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: align,
          style: mgText(c, size: 15, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          textAlign: align,
          style: mgText(c).copyWith(color: c.fg2),
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = MgColors.of(context).dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: dark ? const Color(0xFFFF453A) : const Color(0xFFD70015),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = onTap != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: enabled || busy ? 1 : 0.45,
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: busy
                  ? const CupertinoActivityIndicator(
                      color: Color(0xFFFFFFFF),
                      radius: 8,
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(color: MgColors.of(context).accent),
          ),
        ),
      ),
    ),
  );
}
