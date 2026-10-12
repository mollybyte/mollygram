import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_prototype/app_state.dart';
import 'package:mollygram_prototype/circle/circle_controller.dart';
import 'package:mollygram_prototype/main.dart';

import 'authorization_panel.dart';
import 'telegram_session_launcher.dart';

class MollygramApp extends StatefulWidget {
  const MollygramApp({super.key, required this.config, this.launcher});

  final TelegramApiConfig config;
  final TelegramSessionLauncher? launcher;

  @override
  State<MollygramApp> createState() => _MollygramAppState();
}

class _MollygramAppState extends State<MollygramApp> {
  late final _app = AppState();
  late final _circle = CircleController(enabled: false);
  late final Future<TelegramSession>? _session = widget.config.isConfigured
      ? (widget.launcher ?? TelegramSessionLauncher()).start(widget.config)
      : null;

  @override
  void dispose() {
    unawaited(_session?.then((session) => session.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final future = _session;
    if (future == null) return _shell();
    return FutureBuilder<TelegramSession>(
      future: future,
      builder: (context, snapshot) {
        final session = snapshot.data;
        if (session == null) return _shell();
        return StreamBuilder<AuthorizationStage>(
          stream: session.authorization.stages,
          initialData: session.authorization.currentStage,
          builder: (context, state) => _shell(
            state.data?.kind == AuthorizationStageKind.ready
                ? null
                : _Overlay(session: session, stage: state.data),
          ),
        );
      },
    );
  }

  Widget _shell([Widget? foreground]) =>
      PrototypeApp(app: _app, circle: _circle, foreground: foreground);
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.session, this.stage});
  final TelegramSession session;
  final AuthorizationStage? stage;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x66000000),
    child: AuthorizationPanel(
      stage: stage ?? AuthorizationStage.unavailable(),
      submitPhone: (value) =>
          unawaited(session.authorization.submitPhone(value)),
      requestQrCode: () => unawaited(session.authorization.requestQrCode()),
      submitCode: (value) => unawaited(session.authorization.submitCode(value)),
      submitPassword: (value) =>
          unawaited(session.authorization.submitPassword(value)),
    ),
  );
}
