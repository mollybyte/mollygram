import 'package:flutter/material.dart';

import '../circle/circle_controller.dart';
import '../glass.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fake_data.dart';
import 'message_view.dart';

/// Переписка: лента уходит под плавающие шапку и поле ввода.
class ChatPane extends StatefulWidget {
  const ChatPane({
    super.key,
    required this.chat,
    required this.messages,
    required this.scroll,
    required this.circle,
  });

  final FakeChat chat;
  final List<FakeMessage> messages;
  final ScrollController scroll;
  final CircleController circle;

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  bool _ghost = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final msgs = widget.messages;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: ListView.builder(
              controller: widget.scroll,
              reverse: true,
              padding: const EdgeInsets.only(top: 72, bottom: 88),
              itemCount: msgs.length,
              itemBuilder: (context, i) {
                final m = msgs[i];
                final newer = i > 0 ? msgs[i - 1] : null;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: MessageView(
                        msg: m,
                        newerSameSide:
                            newer != null &&
                            newer.kind != MsgKind.date &&
                            newer.out == m.out,
                        circle: widget.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Шапка: две стеклянные капсулы.
        Positioned(
          top: 10,
          left: 14,
          right: 14,
          height: 44,
          child: Row(
            children: [
              Glass(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(widget.chat.initials, size: 32),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.chat.name,
                          style: mgText(
                            c,
                            size: 13.5,
                            weight: FontWeight.w600,
                          ).copyWith(height: 1.2),
                        ),
                        Text(
                          _ghost && widget.chat.status.isNotEmpty
                              ? '${widget.chat.status} · вы невидимы'
                              : widget.chat.status,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.2,
                            color: c.fg2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Expanded(child: WindowDragArea()),
              Glass(
                radius: 22,
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconBtn(MgIcons.search, tooltip: 'Поиск в чате'),
                    const SizedBox(width: 2),
                    const IconBtn(MgIcons.call, tooltip: 'Позвонить'),
                    const SizedBox(width: 2),
                    IconBtn(
                      MgIcons.ghost,
                      tooltip: 'Режим призрака',
                      on: _ghost,
                      onTap: () => setState(() => _ghost = !_ghost),
                    ),
                    const SizedBox(width: 2),
                    const IconBtn(MgIcons.panel, tooltip: 'Информация о чате'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Поле ввода.
        Positioned(
          left: 24,
          right: 24,
          bottom: 12,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 712),
              child: const _Composer(),
            ),
          ),
        ),
        // Кружок продолжает играть в углу, когда его сообщение уехало.
        Positioned(
          right: 24,
          bottom: 72,
          child: ListenableBuilder(
            listenable: widget.circle,
            builder: (context, _) {
              final circle = widget.circle;
              if (!circle.playing || circle.inList) {
                return const SizedBox.shrink();
              }
              return DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleVideo(controller: circle, size: 160),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final hasDraft = _text.text.isNotEmpty;
    return Glass(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      child: Row(
        children: [
          const IconBtn(MgIcons.attach, tooltip: 'Прикрепить', size: 18),
          const SizedBox(width: 2),
          Expanded(
            child: SizedBox(
              height: 32,
              child: Center(
                child: TextField(
                  controller: _text,
                  style: mgText(c, size: 13.5),
                  cursorHeight: 16,
                  decoration: InputDecoration.collapsed(
                    hintText: 'Сообщение',
                    hintStyle: mgText(c, size: 13.5).copyWith(color: c.fg2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          const IconBtn(MgIcons.emoji, tooltip: 'Эмодзи и стикеры', size: 18),
          const SizedBox(width: 2),
          if (hasDraft)
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
              ),
              child: const DefaultTextStyle(
                style: TextStyle(color: Colors.white),
                child: MgIcon(MgIcons.send, size: 16, stroke: 2.2),
              ),
            )
          else
            const IconBtn(
              MgIcons.mic,
              tooltip: 'Записать голосовое или кружок',
              size: 18,
            ),
        ],
      ),
    );
  }
}
