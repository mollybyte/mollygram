import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_prototype/app_state.dart';
import 'package:mollygram_prototype/chat/fake_data.dart';
import 'package:mollygram_prototype/circle/circle_controller.dart';
import 'package:mollygram_prototype/main.dart';
import 'package:mollygram_prototype/sidebar.dart';

import 'authorization_panel.dart';
import 'prototype_chat_adapter.dart';
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
        if (snapshot.hasError) {
          return _shell(
            foreground: _StartupError(message: snapshot.error.toString()),
          );
        }
        final session = snapshot.data;
        if (session == null) return _shell();
        return StreamBuilder<AuthorizationStage>(
          stream: session.authorization.stages,
          initialData: session.authorization.currentStage,
          builder: (context, state) {
            if (state.data?.kind != AuthorizationStageKind.ready) {
              return _shell(
                foreground: _Overlay(session: session, stage: state.data),
              );
            }
            return StreamBuilder<void>(
              stream: session.chatLists.changes,
              builder: (context, _) {
                final chats = PrototypeChatAdapter.chatsFor(
                  session.chatLists.store,
                  const ChatListLocation.main(),
                );
                return _shell(
                  chats: chats.isEmpty ? null : chats,
                  folders: PrototypeChatAdapter.foldersFor(
                    session.chatLists.store,
                  ),
                  onSend: (chat, text) =>
                      unawaited(session.conversations.sendText(chat.id, text)),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _shell({
    Widget? foreground,
    List<FakeChat>? chats,
    List<PrototypeFolder>? folders,
    void Function(FakeChat chat, String text)? onSend,
  }) => PrototypeApp(
    app: _app,
    circle: _circle,
    foreground: foreground,
    chats: chats,
    folders: folders,
    onSend: onSend,
  );
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

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x66000000),
    child: Center(
      child: Material(
        borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
      ),
    ),
  );
}
