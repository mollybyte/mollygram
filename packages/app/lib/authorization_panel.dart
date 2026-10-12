import 'package:flutter/material.dart';
import 'package:mollygram_core/mollygram_core.dart';

/// Compact sign-in surface driven by [AuthorizationStage] from TDLib.
///
/// It contains no Telegram credentials and no TDLib setup logic. The desktop
/// session owns those concerns and supplies callbacks once it is running.
class AuthorizationPanel extends StatefulWidget {
  const AuthorizationPanel({
    super.key,
    required this.stage,
    required this.submitPhone,
    required this.requestQrCode,
    required this.submitCode,
    required this.submitPassword,
  });

  final AuthorizationStage stage;
  final ValueChanged<String> submitPhone;
  final VoidCallback requestQrCode;
  final ValueChanged<String> submitCode;
  final ValueChanged<String> submitPassword;

  @override
  State<AuthorizationPanel> createState() => _AuthorizationPanelState();
}

class _AuthorizationPanelState extends State<AuthorizationPanel> {
  final _input = TextEditingController();

  @override
  void didUpdateWidget(covariant AuthorizationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage.kind != widget.stage.kind) _input.clear();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (widget.stage.kind) {
      AuthorizationStageKind.phoneNumber => _Form(
        key: const ValueKey('phone'),
        title: 'Sign in to Telegram',
        description: 'Enter your phone number in international format.',
        label: 'Phone number',
        action: 'Continue',
        keyboardType: TextInputType.phone,
        onSubmit: widget.submitPhone,
      ),
      AuthorizationStageKind.qrCode => _Qr(
        link: widget.stage.qrLink,
        onPhone: widget.requestQrCode,
      ),
      AuthorizationStageKind.code => _Form(
        key: const ValueKey('code'),
        title: 'Enter confirmation code',
        description: 'Telegram sent a sign-in code to your device or phone.',
        label: 'Code',
        action: 'Confirm',
        keyboardType: TextInputType.number,
        onSubmit: widget.submitCode,
      ),
      AuthorizationStageKind.password => _Form(
        key: const ValueKey('password'),
        title: 'Two-step verification',
        description: 'Enter your Telegram password.',
        label: 'Password',
        action: 'Continue',
        obscureText: true,
        onSubmit: widget.submitPassword,
      ),
      AuthorizationStageKind.tdlibParameters => const _Status(
        title: 'Preparing secure storage',
        description: 'Mollygram is starting Telegram securely.',
      ),
      AuthorizationStageKind.ready => const _Status(
        title: 'Signed in',
        description: 'Loading your chats…',
      ),
      AuthorizationStageKind.unavailable => const _Status(
        title: 'Telegram is unavailable',
        description: 'Please try again shortly.',
      ),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surface,
          child: Padding(padding: const EdgeInsets.all(24), child: content),
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    super.key,
    required this.title,
    required this.description,
    required this.label,
    required this.action,
    required this.onSubmit,
    this.keyboardType,
    this.obscureText = false,
  });

  final String title;
  final String description;
  final String label;
  final String action;
  final ValueChanged<String> onSubmit;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final input = context.findAncestorStateOfType<_AuthorizationPanelState>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(title: title, description: description),
        const SizedBox(height: 20),
        TextField(
          controller: input._input,
          autofocus: true,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onSubmitted: onSubmit,
          decoration: InputDecoration(labelText: label),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => onSubmit(input._input.text),
            child: Text(action),
          ),
        ),
      ],
    );
  }
}

class _Qr extends StatelessWidget {
  const _Qr({required this.link, required this.onPhone});

  final String? link;
  final VoidCallback onPhone;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading(
        title: 'Scan this QR code',
        description: 'Open Telegram on another device and scan the code.',
      ),
      const SizedBox(height: 20),
      SelectableText(link ?? 'Waiting for a QR code…'),
      const SizedBox(height: 16),
      TextButton(onPressed: onPhone, child: const Text('Use phone number')),
    ],
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 20),
      _Heading(title: title, description: description),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(description, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}
