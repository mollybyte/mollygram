import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' show TdException;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import '../window_drag_area.dart';
import 'country_picker.dart';
import 'qr_view.dart';

/// Sign-in as in the official Telegram apps: a plain window with one
/// centered column. The QR code comes first; the phone number is one click
/// away.
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
    if (stage != null) return _SignInFlow(stage: stage);
    return SignInPage(
      titleBarFill: const WindowDragArea(),
      child: title != null
          ? SignInHeader(title: title, subtitle: _description)
          : const _Starting(),
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

/// What the user is looking at, which is not always TDLib's step: the
/// phone form can be opened over the QR code, and over the code step to
/// change the number.
enum _View { qr, phone, countries, code, password, waiting, unsupported }

class _SignInFlow extends ConsumerStatefulWidget {
  const _SignInFlow({required this.stage});

  final AuthorizationStage stage;

  @override
  ConsumerState<_SignInFlow> createState() => _SignInFlowState();
}

class _SignInFlowState extends ConsumerState<_SignInFlow> {
  final _code = TextEditingController(text: '+');
  final _number = TextEditingController();
  final _numberFocus = FocusNode();
  final _input = TextEditingController();

  bool _wantsPhone = false;
  bool _picking = false;
  bool _busy = false;
  String? _error;
  List<PhoneCountry> _countries = const [];
  PhoneCountry? _country;
  String? _homeCountry;

  AuthorizationStageKind get _kind => widget.stage.kind;

  @override
  void initState() {
    super.initState();
    _code.addListener(_codeChanged);
    _number.addListener(_redraw);
    _input.addListener(_redraw);
    _requestQrIfNeeded();
    _loadCountries();
  }

  @override
  void didUpdateWidget(_SignInFlow old) {
    super.didUpdateWidget(old);
    if (old.stage.kind == _kind) return;
    _error = null;
    _input.clear();
    if (_kind == AuthorizationStageKind.code ||
        _kind == AuthorizationStageKind.password) {
      _wantsPhone = false;
      _picking = false;
    }
    _requestQrIfNeeded();
  }

  @override
  void dispose() {
    _code.dispose();
    _number.dispose();
    _numberFocus.dispose();
    _input.dispose();
    super.dispose();
  }

  void _redraw() => setState(() {});

  _View get _view {
    final phoneStep =
        _kind == AuthorizationStageKind.phoneNumber ||
        _kind == AuthorizationStageKind.qrCode ||
        _kind == AuthorizationStageKind.code;
    if (_wantsPhone && phoneStep) {
      return _picking ? _View.countries : _View.phone;
    }
    return switch (_kind) {
      AuthorizationStageKind.phoneNumber ||
      AuthorizationStageKind.qrCode => _View.qr,
      AuthorizationStageKind.code => _View.code,
      AuthorizationStageKind.password => _View.password,
      AuthorizationStageKind.tdlibParameters ||
      AuthorizationStageKind.ready => _View.waiting,
      AuthorizationStageKind.unavailable => _View.unsupported,
    };
  }

  void _requestQrIfNeeded() {
    if (_kind != AuthorizationStageKind.phoneNumber || _wantsPhone) return;
    // A failed QR request (no network, say) falls back to the phone form.
    ref.read(signInActionsProvider).requestQrCode().catchError((Object error) {
      if (mounted) _fail(error, showPhone: true);
    });
  }

  Future<void> _loadCountries() async {
    final actions = ref.read(signInActionsProvider);
    try {
      final (countries, home) = await (
        actions.countries(),
        actions.currentCountryCode(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _homeCountry = home;
      });
      final current = countries.where((c) => c.code == home).firstOrNull;
      if (current != null && _code.text == '+') _selectCountry(current);
    } catch (_) {
      // The form still works with a typed code; only the name is missing.
    }
  }

  void _codeChanged() {
    final digits = _code.text.replaceAll(RegExp(r'\D'), '');
    final country = countryForDigits(
      _countries,
      digits,
      preferred: _country?.code ?? _homeCountry,
    );
    if (country?.code != _country?.code) setState(() => _country = country);
    if (!_code.text.startsWith('+')) {
      _code.value = TextEditingValue(
        text: '+$digits',
        selection: TextSelection.collapsed(offset: digits.length + 1),
      );
    }
  }

  void _selectCountry(PhoneCountry country) {
    setState(() {
      _country = country;
      _picking = false;
    });
    _code.text = '+${country.callingCodes.first}';
    _numberFocus.requestFocus();
  }

  Future<void> _run(Future<void> Function() request) async {
    if (_busy) return;
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

  void _openPhone() => setState(() {
    _wantsPhone = true;
    _error = null;
  });

  void _openQr() {
    setState(() {
      _wantsPhone = false;
      _error = null;
    });
    _requestQrIfNeeded();
  }

  String get _phoneDigits =>
      (_code.text + _number.text).replaceAll(RegExp(r'\D'), '');

  void _submitPhone() {
    if (_number.text.trim().isEmpty) return;
    final actions = ref.read(signInActionsProvider);
    _run(() async {
      await actions.submitPhone('+$_phoneDigits');
      if (mounted) setState(() => _wantsPhone = false);
    });
  }

  void _submitInput() {
    final value = _input.text;
    if (value.trim().isEmpty) return;
    final actions = ref.read(signInActionsProvider);
    _run(
      () => _kind == AuthorizationStageKind.password
          ? actions.submitPassword(value)
          : actions.submitCode(value.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = _view;
    return SignInPage(
      titleBarFill: const WindowDragArea(),
      backTooltip: l10n.back,
      onBack: switch (view) {
        _View.countries => () => setState(() => _picking = false),
        _View.phone when _kind != AuthorizationStageKind.code => _openQr,
        _View.phone => () => setState(() => _wantsPhone = false),
        _View.code => _openPhone,
        _ => null,
      },
      child: KeyedSubtree(
        key: ValueKey(view),
        child: switch (view) {
          _View.qr => _qr(l10n),
          _View.phone => _phone(l10n),
          _View.countries => CountryPicker(
            countries: _countries,
            searchHint: l10n.searchHint,
            emptyText: l10n.nothingFound,
            onSelected: _selectCountry,
          ),
          _View.code => _form(
            title: widget.stage.phoneNumber,
            subtitle: switch (widget.stage.codeDelivery) {
              CodeDelivery.app => l10n.codeSentApp,
              CodeDelivery.sms => l10n.codeSentSms,
              CodeDelivery.call => l10n.codeSentCall,
              CodeDelivery.other => l10n.codeSentOther,
            },
            hint: l10n.codeHint,
            keyboardType: TextInputType.number,
            center: true,
          ),
          _View.password => _form(
            title: l10n.passwordTitle,
            subtitle: widget.stage.passwordHint.isEmpty
                ? l10n.passwordHint
                : l10n.passwordHintWithHint(widget.stage.passwordHint),
            hint: l10n.passwordFieldHint,
            obscureText: true,
          ),
          _View.waiting => const _Starting(),
          _View.unsupported => SignInHeader(
            title: l10n.unsupportedTitle,
            subtitle: l10n.unsupportedStep,
          ),
        },
      ),
    );
  }

  Widget _qr(AppLocalizations l10n) {
    final link = widget.stage.qrLink;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SignInHeader(
          leading: QrFrame(
            qr: link == null
                ? const Center(child: CupertinoActivityIndicator())
                : QrView(data: link, color: const Color(0xFF000000)),
            center: link == null
                ? null
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/app_icon.png',
                      width: 36,
                      height: 36,
                      semanticLabel: l10n.appTitle,
                    ),
                  ),
          ),
          title: l10n.qrTitle,
        ),
        const SizedBox(height: 24),
        SignInSteps(steps: [l10n.qrStep1, l10n.qrStep2, l10n.qrStep3]),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorText(_error!),
        ],
        const SizedBox(height: 28),
        Center(
          child: MgTextButton(label: l10n.logInByPhone, onPressed: _openPhone),
        ),
      ],
    );
  }

  Widget _phone(AppLocalizations l10n) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SignInHeader(title: l10n.phoneTitle, subtitle: l10n.phoneHint),
      const SizedBox(height: 28),
      PhoneNumberField(
        country: _country?.name ?? l10n.country,
        onCountryTap: _countries.isEmpty
            ? null
            : () => setState(() => _picking = true),
        codeController: _code,
        numberController: _number,
        numberFocusNode: _numberFocus,
        numberHint: l10n.phoneNumberHint,
        errorText: _error,
        onSubmitted: (_) => _submitPhone(),
      ),
      const SizedBox(height: 32),
      MgPrimaryButton(
        label: l10n.next,
        expand: true,
        height: 42,
        loading: _busy,
        onPressed: _number.text.trim().isEmpty ? null : _submitPhone,
      ),
      if (_kind != AuthorizationStageKind.code) ...[
        const SizedBox(height: 16),
        Center(
          child: MgTextButton(label: l10n.logInByQr, onPressed: _openQr),
        ),
      ],
    ],
  );

  Widget _form({
    required String title,
    required String subtitle,
    required String hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool center = false,
  }) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SignInHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 28),
        MgUnderlineField(
          controller: _input,
          hintText: hint,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofocus: true,
          textAlign: center ? TextAlign.center : TextAlign.start,
          errorText: _error,
          onSubmitted: (_) => _submitInput(),
        ),
        const SizedBox(height: 32),
        MgPrimaryButton(
          label: l10n.next,
          expand: true,
          height: 42,
          loading: _busy,
          onPressed: _input.text.trim().isEmpty ? null : _submitInput,
        ),
      ],
    );
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

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: mgTextStyle(
      MgColors.of(context),
      size: MgType.small,
      color: MgUnderlineField.errorColor,
    ),
  );
}
